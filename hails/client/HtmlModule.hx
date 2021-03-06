package hails.client ;
import hails.client.JSContext;
import hails.util.StringUtil;
import haxe.ds.StringMap;
import haxe.rtti.Meta;
#if js
import js.Browser;
#end
import hails.client.ClientProgram;

/**
 * To use this, you must first install the jqueryextern library:
 *		haxelib install jqueryextern
 * To use it with your hails app you must also add it to jslibs in config/haxeconfig:
 * 		jslibs: jqueryextern
 *
 * 	(hx-files in your <project>/javascript folder having a main-method will be compiled with these jslibs,
 *   and will be placed in the root-webfolder with name specified on the class with @:javascript("myjavascriptfile.js")
 * 
 * Example usage of HtmlModule: Extend this class and call it MyTestModule.
 * Then on "new MyTestModule()" it will try to load "/my_test_module.html?v=1" from the server and inject it into the DIV with id="MyTestModule".
 * Use HtmlModule.setBaseHtmlFolder("/modules") to load the html-files from /modules instead of from server root.
 * To override the default injection-div: Specify @inject("#myDiv") to instead inject it into the DIV with id="myDiv".
 * To cache html in localStorage, call HtmlModule.setCacheInLocalStorageAsDefault(true);
 * It will be stored in localStorage with version="1".
 * When you update the HTML you can specify on your HtmlModule-class: @version("2")
 * If this version differs from what is in the cache, the cache will be updated.
 */
class HtmlModule extends ClientProgram
{
	public var loaded(default, null) : Bool;
	public var loading(default, null) : Bool;
	public var html(default, null) : String;
	public var injecting(default, null) : Bool;
	public var injected(default, null) : Bool;
	private var injectAtSelector:String = null;
	private var onloaded:Void->Void = null;
	
	public function new(master:ModuleMaster, injectAtSelector:String = null, onloaded:Void->Void = null) 
	{
		super(master);
		trace("constructing: " + Type.getClassName(Type.getClass(this)));
		this.master = master;
		this.loaded = false;
		this.loading = false;
		this.injected = false;
		this.injecting = true;
		this.html = null;
		this.injectAtSelector = injectAtSelector;
		this.onloaded = onloaded;
		master.loadedModules.push(this);
		initiate();
	}
	
	public function goToPage(pageId:String, pageContent:String = null) {
		master.goToPage(pageId, pageContent);
	}
	
	function module < T : HtmlModule > (moduleClass:Class<T>) : T {
		return master.module(moduleClass);
	}

	
	public function setBaseHtmlFolder(folder:String) {
		master.setBaseHtmlFolder(folder);
	}
	
	public function setCacheInLocalStorageAsDefault(cache:Bool) {
		master.cacheInLocalStorageAsDefault = cache;
	}
	public function cacheInLocalStorage() : Bool {
		return master.cacheInLocalStorageAsDefault;
	}

	
	public function moduleLoaded() {
		// Override to set up stuff like events etc.
	}
	
	function thisSimpleClassName() {
		var fullName = Type.getClassName(Type.getClass(this));
		var parts = fullName.split(".");
		var simpleName = parts[parts.length - 1];
		return simpleName;
	}
	
	function getHtmlPath(includeVersion = true) : String {
		var relPath = null;
		var meta = Meta.getType(Type.getClass(this));
		if ((meta.html != null) && meta.html.length >= 1) {
			relPath = meta.html[0];
		} else {
			var simpleName = thisSimpleClassName();
			if (StringTools.endsWith(simpleName, "Module")) {
				simpleName = simpleName.substring(0, simpleName.length - "Module".length);
			}
			simpleName = StringUtil.tableize(simpleName);
			relPath = simpleName + ".html";
		}
		if (StringTools.startsWith(relPath, "/")) {
			relPath = relPath.substr(1);
		}

		return JSContext.getStaticRootUrl() + master.baseHtmlFolder + relPath + (includeVersion ? "?v=" + getVersion() : "");
	}

	private function initiate() {
		doLoadHtml(doInject);
	}
	
	/**
	 * Retry any modules that could not be injected, because maybe they depend on "this"
	 */
	private function retryOtherPendingModules() {
		for (mod in master.pendingInjections) {
			if (!mod.injecting) {
				mod.doInject();
			}
		}
	}
	
	private function doLoadHtml(callback:Void->Void = null) {
		this.loading = true;
		trace("cacheInLocalStorage()=" + cacheInLocalStorage());
		if (cacheInLocalStorage()) {
			var cache = getHtmlFromLocalStorage();
			if (cache != null) {
				this.loading = false;
				this.html = cache;
				this.loaded = true;
				if (callback != null) {
					callback();
				}
			}
		}
		trace("doLoadHtml:" + getHtmlPath());
		get(getHtmlPath(), null, function(data:Dynamic, status:String, jqhxr:JqXHR) {
			this.loading = false;
			this.html = data;
			if (cacheInLocalStorage()) {
				saveToLocalStorage(data);
			}
			this.loaded = true;
			//trace("loaded " + getHtmlPath());
			//trace("callback=" + callback);
			if (callback != null) {
				//trace("calling callback");
				callback();
			}
		});		
	}
	
	private function callOnLoaded() {
		moduleLoaded();
		if (onloaded != null) {
			onloaded();
		}		
	}
	
	private function doInject() {
		//trace("doInject");
		if (injected) {
			return;
		}
		if (html == null) {
			throw "no HTML to inject (loading=" + loading + " loaded=" + loaded + ")";
		}
		var injectAt = getInjectAt();
		//trace("injectAt=" + injectAt);
		if (injectAt == null || injectAt.length == 0) {
			callOnLoaded();
			return;
		}
		this.injecting = true;
		var count = 0;
		for (injectionPlace in injectAt) {
			var jq = jquery(injectionPlace);
			if (jq.length > 0) {
				jq.html(html);
				count++;
			}
		}
		if (count == 0) {
			trace("no injection-point found for " + Std.string(injectAt));
			if (master.pendingInjections.indexOf(this) < 0) {
				master.pendingInjections.push(this);
			}
		} else {
			this.injected = true;
			if (master.pendingInjections.indexOf(this) >= 0) {
				master.pendingInjections.remove(this);
			}
			callOnLoaded();
			retryOtherPendingModules();
		}
		this.injecting = false;
	}
	
	private function getInjectAt() : Array<String> {
		if (injectAtSelector != null) {
			return [injectAtSelector];
		}
		var meta = Meta.getType(Type.getClass(this));
		if ((meta.inject != null) && meta.inject.length >= 1) {
			return cast(meta.inject);
		}
		var defaultInjector = "#" + thisSimpleClassName();
		return [defaultInjector];
	}
	
	private function getVersion() : String {
		var meta = Meta.getType(Type.getClass(this));
		if ((meta.version != null) && meta.version.length >= 1) {
			return cast(meta.version);
		}
		return "1";
	}
	
	private function saveToLocalStorage(htmlData:String) {
		#if js
		var key = getHtmlPath();
		var storage = Browser.getLocalStorage();
		storage.setItem(key, getVersion() + "!" + htmlData);
		#end
	}
	
	private function getHtmlFromLocalStorage() {
		#if js
		var key = getHtmlPath();
		var storage = Browser.getLocalStorage();
		var data = storage.getItem(key);
		if (data == null) {
			return null;
		}
		var versionStringLength = data.indexOf("!");
		var version = data.substr(0, versionStringLength);
		if (version == getVersion()) {
			return data.substr(versionStringLength + 1);
		}
		#end
		return null;
	}
	
	public function handleHashChanged(hash:String) {
		master.handleHashChanged(hash);
	}
	
	public function handleNavigation(command:String, params:StringMap<String>) {
	}
	
	/////// helper methods:
	#if js
	public static inline function JQueryThis() : JQuery {
		return new JQuery(untyped __js__("this"));
	}
	#end
	
}