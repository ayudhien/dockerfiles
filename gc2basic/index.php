<?php
ini_set("display_errors", "Off");
ini_set('memory_limit', '256M');
error_reporting(3);

use \app\inc\Input;
use \app\inc\Session;
use \app\inc\Route;
use \app\inc\Util;
use \app\conf\Connection;
use \app\conf\App;
use \app\models\Database;

include_once("../app/conf/App.php");
new \app\conf\App();

App::$param['protocol'] = App::$param['protocol'] ?: Util::protocol();
App::$param['host'] = App::$param['host'] ?: App::$param['protocol'] . "://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'];
App::$param['userHostName'] = App::$param['userHostName'] ?: App::$param['host'];

// Start routing
if (Input::getPath()->part(1) == "api") {
    Database::setDb(Input::getPath()->part(4)); // Default
    Route::add("api/v1/sql", function () {
        $db = Input::getPath()->part(4);
        $dbSplit = explode("@", $db);
        if (sizeof($dbSplit) == 2) {
            $db = $dbSplit[1];
            Session::start();
            $_SESSION['subuser'] = $dbSplit[0];
        }
        Database::setDb($db);
    });
    Route::add("api/v1/meta", function () {
        Session::start();
    });
    Route::add("api/v1/extent");
    Route::add("api/v1/schema");
    Route::add("api/v1/setting");
    Route::add("api/v1/user");
    Route::add("api/v1/legend", function () {
        Database::setDb(Input::getPath()->part(5));
        Connection::$param["postgisschema"] = "trackunit";
    });
    Route::add("api/v1/baselayerjs");
    Route::add("api/v1/getheader");
} elseif (Input::getPath()->part(1) == "store") {
    Session::start();
    Session::authenticate(App::$param['userHostName'] . "/user/login/");
    $_SESSION['postgisschema'] = (Input::getPath()->part(3)) ?: "public";
    include_once("store.php");
    if (\app\conf\App::$param['intercom_io']) {
        include_once("../app/conf/intercom.js.inc");
    }
} elseif (Input::getPath()->part(1) == "editor") {
    Session::start();
    Session::authenticate(App::$param['userHostName'] . "/user/login/");
    include_once("editor.php");
} elseif (Input::getPath()->part(1) == "controllers") {
    Session::start();
    Session::authenticate(null);

    Database::setDb($_SESSION['screen_name']);
    Connection::$param["postgisschema"] = $_SESSION['postgisschema'];

    Route::add("controllers/cfgfile");
    Route::add("controllers/classification/");
    Route::add("controllers/database/");
    Route::add("controllers/layer/");
    Route::add("controllers/mapfile");
    Route::add("controllers/setting");
    Route::add("controllers/table/");
    Route::add("controllers/tile/");
    Route::add("controllers/tilecache/");
    Route::add("controllers/session/");
} elseif (Input::getPath()->part(1) == "wms" || Input::getPath()->part(1) == "ows") {
    Session::start();
    new \app\controllers\Wms();
} elseif (!Input::getPath()->part(1)) {
    if (App::$param["redirectTo"]) {
        \app\inc\Redirect::to(App::$param["redirectTo"]);
    } else {
        \app\inc\Redirect::to("/user/login");
    }
} else {
    header('HTTP/1.0 404 Not Found');
    echo "<h1>404 Not Found</h1>";
    echo "The page that you have requested could not be found.";
    exit();
}