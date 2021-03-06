package ;

import hails.config.ConfigReader;
import hails.platform.Platform;
import haxe.ds.StringMap;
import haxe.io.Path;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;
import hails.platform.Platform;

class JavascriptBuilder extends HailsBuilder
{

	public function new() {	}
	
	public function build(hailsPath:String, workPath:String, dest:String, define:String) {
		var directory = "javascript";
		var controllers:Array<String> = new Array<String>();
		if (FileSystem.exists (directory) && FileSystem.isDirectory (directory)) {
			for (file in FileSystem.readDirectory (directory)) {
				var i = file.indexOf(".hx");
				if (i > 0) {
					var className = file.substring(0, i);
					var outfile:String = null;
					var main:String = null;
					var content = File.getContent(directory + "/" + file);
					for (line in content.split("\n")) {
						line = StringTools.trim(line);
						var pre = "@:javascript(\"";
						var post = "\")";
						if (StringTools.startsWith(line, pre) && StringTools.endsWith(line, post)) {
							outfile = line.substring(pre.length, line.indexOf(post));
							main = directory + "." + className;
						}
					}
					outfile = dest + "/" + outfile;
					Platform.println("Building JS-file " + outfile);
					if (outfile != null) {
						var haxeArgs = ["-js", outfile, "-main", main, "-cp", ".", "-lib", "hails"].concat(getHaxeLibArgs());
						if (define != null) {
							haxeArgs = haxeArgs.concat(["-D", define]);
						}
						RunScript.runCommand(workPath, "haxe", haxeArgs);
					}
				}
			}
		}
	}
	
	
	public override function getNeededLibs() : Array<String> {
		var conf = getHaxeConfig();
		if (conf == null) {
			return new Array<String>();
		}
		var libList = conf.get("jslibs");
		if ((libList == null) || (libList.length == 0)) {
			return new Array<String>();
		}
		return libList.split(",");
	}
	public override function getHaxeLibArgs() {
		var ret = new Array<String>();
		for (lib in getNeededLibs()) {
			ret.push("-lib");
			ret.push(lib);
		}
		return ret;
	}	
	
}