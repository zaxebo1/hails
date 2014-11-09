package test.unit.dispatcher;
import controller.MainController;
import controller.TestController1;
import hails.HailsController;
import hails.HailsControllerMethodFinder;
import hails.HailsDispatcher;
import hails.util.test.FakeWebContext;
import haxe.ds.StringMap;
import haxe.rtti.Meta;
import haxe.unit.TestCase;
import test.unit.dispatcher.InitControllerTest;

@path("/")
class MainTestController extends HailsController {
	@GET
	public function index() {}
	@POST
	public function store() {}
}
@path("/user/{userid?}")
class UserTestController extends HailsController {
	@GET
	public function index() {}
	@POST
	public function update() {}
	@PUT
	public function insert() {}
	@DELETE
	public function delete() {}
}
@path("car")
class CarTestController extends HailsController {
	@GET
	public function index() {}
}
@path("road/{roadNo}")
class RoadTestController extends HailsController {
	@GET
	public function index() {}
}
class PathLessTestController extends HailsController {
	@GET
	public function index() { }
	@action
	public function actionByFunctionName() { }
	@action("myactionname")
	public function actionByAnnotation() {	}
	@action("postonly")
	@POST
	public function postActionByAnnotation() {	}
}

class MatchPathControllerTest extends TestCase
{
	static var controllers:Array<Class<HailsController>> = 
		[MainTestController, UserTestController, PathLessTestController, CarTestController,
		RoadTestController];

	public function testRootPath() {
		doTest("/", "GET", MainTestController, "index", strmap({}));
		doTest("/", "POST", MainTestController, "store", strmap({}));
	}
	
	public function testPathWithOptionalVariable() {
		doTest("/user/", "GET", UserTestController, "index", strmap({"userid" : null}));
		doTest("/user/", "POST", UserTestController, "update", strmap({"userid" : null}));
		doTest("/user/", "PUT", UserTestController, "insert", strmap({"userid" : null}));
		doTest("/user/", "DELETE", UserTestController, "delete", strmap({"userid" : null}));
		doTest("/user/123", "GET", UserTestController, "index", strmap({"userid" : "123"}));
		doTest("/user/123", "POST", UserTestController, "update", strmap({"userid" : "123"}));
		doTest("/user/123", "PUT", UserTestController, "insert", strmap({"userid" : "123"}));
		doTest("/user/123", "DELETE", UserTestController, "delete", strmap( { "userid" : "123" } ));		
	}
		
	public function testPathWithRequiredVariable() {
		doTest("/road/", "GET", null,null,null);
		doTest("/road/123", "GET", RoadTestController, "index", strmap( { "roadNo" : "123" } ));
	}
		
	public function testPathWithoutVariable() {
		doTest("/car/", "GET", CarTestController, "index", strmap({}));
		doTest("/car/123", "GET", null, null, null);
	}
	
	public function testPathLessController() {
		doTest("/path_less_test/", "GET", PathLessTestController, "index", strmap({}));
		doTest("/path_less_test/action_by_function_name", "GET", PathLessTestController, "actionByFunctionName", strmap({}));
		doTest("/path_less_test/myactionname", "GET", PathLessTestController, "actionByAnnotation", strmap({}));
		doTest("/path_less_test/postonly", "POST", PathLessTestController, "postActionByAnnotation", strmap({}));
		doTest("/path_less_test/postonly", "GET", null,null,null);
	}
	
	function strmap(d : Dynamic) {
		var ret = new StringMap<String>();
		for (key in Reflect.fields(d)) {
			ret.set(cast(key), cast(Reflect.field(d, key)));
		}
		return ret;
	}
	
	function doTest(uri:String, method:String, expController:Class<HailsController>, expFunc:String, expVars:StringMap<String>) {
		var ctx = FakeWebContext.fromRelativeUriAndMethod(uri, method);
		var res = HailsControllerMethodFinder.findControllerMethodParams(controllers, ctx);
		if (expController == null) {
			assertFalse(res != null);
			return;
		}
		assertTrue(res != null);
		assertEquals(res.controllerFunction, expFunc);
		assertEquals(res.controller, expController);
		assertEquals(expVars.toString(), res.variables.toString());
	}
	
}

