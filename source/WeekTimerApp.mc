using Toybox.Application as App;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications as Comm;
using Toybox.WatchUi as Ui;
using Toybox.Time;
using Toybox.Time.Gregorian;


class WeekTimerApp extends App.AppBase {

    function initialize() {
      AppBase.initialize();
    }


    function getInitialView() {
      return [ new WeekTimerView(), new WeekTimerBehaviourDelegate() ];
    }
 
}