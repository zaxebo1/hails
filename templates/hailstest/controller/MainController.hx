﻿/**
 * ...
 * @author ...
 */

package controller;
import hails.HailsController;
import model.User;

@path("/")
class MainController extends HailsController
{
	@GET
	public function index() {
		viewData = { theMessage:"Hello world!" };
		
	}
	
	@action
	@PUT
	public function action_add() {
		var u =  new User();
		u.username = 'heisann';
		var a = u.save();
		if (!a) {
			throw "couldnt save";
		}
	}
	
	@action("some_test")
	public function action_someTest() {
		var s = "This is a test!";
		var users = User.findAll();
		for (u in users) {
			s += u.username + "," + Std.string(u);
		}
		viewData = { theMessage:s };
	}
}