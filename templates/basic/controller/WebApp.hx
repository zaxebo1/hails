package controller;
import hails.Main;
import hails.HailsDispatcher;
import controller.MainController;
import controller.WebApp;
class WebApp extends Main
{

	static var tmp = HailsDispatcher.initControllers([MainController]);

	static function main(){
		hails.Main.main();
	}	
}