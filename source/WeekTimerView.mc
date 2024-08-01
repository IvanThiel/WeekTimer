using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Communications as Comm;
import Toybox.Application.Storage;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;
using Toybox.Application as App;
using Toybox.Position;
using Toybox.Background;
using Toybox.ActivityMonitor;


var GlobalTouched = -1;
var mW;
var mH;
var mSH;
var mSW;

var _debug         = false;
var _sound         = false;    
var _usecorrection = true; 
var _test          = false;

class WeekTimerView extends Ui.DataField {
    hidden var YMARGING      = 3;
    hidden var XMARGINGL     = 6;
    hidden var mLastRideDate = "";

    hidden var mDays         = new[3];
    hidden var mValue        = new[3];
    hidden var mCorrect      = new[3];
    hidden var mMonday       = "";
    hidden var mWeekNumber   = "";

    hidden var mCurrentSeries = 0;
    hidden var mState         = 0;

    /******************************************************************
     * INIT 
     ******************************************************************/  
    function initialize() {

      try {
        debug("Monday: "+getMonday());
        DataField.initialize();  

        var n = mDays.size();
        for (var i=0; i<n; i++) {
          mDays[i] = new[7];
        }

        n = mValue.size();
        for (var i=0; i<n; i++) {
          mValue[i] = 0;
        }

        n = mCorrect.size();
        for (var i=0; i<n; i++) {
          mCorrect[i] = 0;
        }

        resetDays();
        loadDays();

        //mBikeRadar = new AntPlus.BikeRadar(new CombiSpeedRadarListener()); 
      } catch (ex) {
        debug ("init error: "+ex.getErrorMessage());
      }         
    }

    function resetDays() {
      var n = mDays.size();
      for (var i=0; i<n; i++) {
        var m = mDays[i].size();
        for (var j=0; j<m; j++) {
          mDays[i][j] = null;
        }
      }
      debug("reset days");
    }

    function debugDays(s) {
      var n = mDays.size();
      debug(s);
      for (var i=0; i<n; i++) {
        var m = mDays[i].size();
        for (var j=0; j<m; j++) {
          debug("day "+i+" "+j+" "+mDays[i][j]);
        }
      }
      debug("lastride: "+mLastRideDate);
      debug("monday: "+mMonday);
    }

    function julian_day(year, month, day) {
        var a = (14 - month) / 12;
        var y = (year + 4800 - a);
        var m = (month + 12 * a - 3);
        return day + ((153 * m + 2) / 5) + (365 * y) + (y / 4) - (y / 100) + (y / 400) - 32045;
    }

    function is_leap_year(year) {
        if (year % 4 != 0) {
            return false;
        } else if (year % 100 != 0) {
            return true;
        } else if (year % 400 == 0) {
            return true;
        }

        return false;
    }

    function iso_week_number(year, month, day) {
        var first_day_of_year = julian_day(year, 1, 1);
        var given_day_of_year = julian_day(year, month, day);

        var day_of_week = (first_day_of_year + 3) % 7; // days past thursday
        var week_of_year = (given_day_of_year - first_day_of_year + day_of_week + 4) / 7;

        // week is at end of this year or the beginning of next year
        if (week_of_year == 53) {

            if (day_of_week == 6) {
                return week_of_year;
            } else if (day_of_week == 5 && is_leap_year(year)) {
                return week_of_year;
            } else {
                return 1;
            }
        }

        // week is in previous year, try again under that year
        else if (week_of_year == 0) {
            first_day_of_year = julian_day(year - 1, 1, 1);

            day_of_week = (first_day_of_year + 3) % 7;

            return (given_day_of_year - first_day_of_year + day_of_week + 4) / 7;
        }

        // any old week of the year
        else {
            return week_of_year;
        }
    }

    function getWeekNumber() {
      var now       = Time.now();
      var date      = Gregorian.info(now, Time.FORMAT_SHORT);

      return iso_week_number(date.year, date.month, date.day);
    }

    function getMonday() {
      var now       = Time.now();
      var date      = Gregorian.info(now, Time.FORMAT_SHORT);
      var dow       = date.day_of_week;

      dow = dow - 2;
      if (dow<0) {
        dow = 6;
      }

      var oneDay    = new Time.Duration(-dow * 3600 * 24);
      var nextday   = now.add(oneDay);
      var fdate     = Gregorian.info(nextday, Time.FORMAT_SHORT);

      var result = Lang.format(
          "$1$/$2$/$3$",
          [
          fdate.day.format("%02d"),
          fdate.month.format("%02d"),
          fdate.year
          ]
       );  

       return result;    
    }

    function saveDays() {
      Storage.setValue("days"    , mDays); 
      Storage.setValue("monday"  , getMonday()); 
      Storage.setValue("lastride", mLastRideDate); 
      Storage.setValue("weeknr  ", getWeekNumber()); 
      debugDays("== saved =="); 
    }
    
    function checkNewWeek() {
      var monday  = Storage.getValue("monday"); 

      if ((monday==null) || (!monday.equals(getMonday()))) {
        debug("NEW WEEK");
        resetDays();
        saveDays();
        loadDays();
        return true;
      } else {
        return false;
      }      
    }

    function loadDays() {
      var days    = Storage.getValue("days"); 
      var last    = Storage.getValue("lastride");  
      var monday  = Storage.getValue("monday"); 
      var week    = Storage.getValue("weeknr");  
    
      if (_test) {
        days[0][0] = 42001;
        days[0][1] = 0;
        days[0][2] = 68110;
        days[0][3] = 92420;
        days[0][4] = 0;
        days[0][5] = 92420;
        days[0][6] = 78000;

        days[1][0] = 529+191;
        days[1][1] = 0;
        days[1][2] = 1145;
        days[1][3] = 1468;
        days[1][4] = 0;
        days[1][5] = 1468;
        days[1][6] = 1000;

        days[2][0] = 100*60*1000;
        days[2][1] = 0;
        days[2][2] = 163*60*1000;
        days[2][3] = 240*60*1000;
        days[2][4] = 0;
        days[2][5] = 240*60*1000;
        days[2][6] = 120*60*1000;       
      }

      if (checkNewWeek()) {
        return;
      }

      if (days!=null) {
        if (days.size()==7) {
          // conversie
          mDays[0] = days;
        } else {
          mDays = days;
        }
      } else {
        resetDays();
        saveDays();
      }

      if (last!=null) {
        if (last.length()>0) {
          mLastRideDate = last;
        }
      }

      if (monday!=null) {
        mMonday = monday;
      }
      
      if (week!=null) {
        mWeekNumber = week;
      } else {
        mWeekNumber = getWeekNumber();
      }
      debugDays("== loaded ==");
    }

    /*
    function getHistory(series) {
      var history = ActivityMonitor.getHistory();
      var result = 0;

      if (history!=null) {
        var n = history.size();
        for (var i=0; i<n; i++) {
          switch (series) {
            case 0: 
              result = result + history[i].distance/1000;
              break;
            case 1:
              result = result + history[i].calories;
              break;
            case 2:
              result = result + history[i].activeMinutes;
              break; 
          }
        }
      }

      return result;
    }
    */

    function getTotal(series) {
      //return getHistory(series);

      var n = mDays[series].size();
      var t = 0;

      for (var i=0; i<n; i++) {
        if (mDays[series][i]!=null) {
          t += mDays[series][i];
        }
      }

      return t;
    }

    function getToDay() {
      var now       = Time.now();
      var oneDay    = new Time.Duration(3600*24*0);
      var nextday   = now.add(oneDay);
      var date      = Gregorian.info(nextday, Time.FORMAT_SHORT);

      return Lang.format(
          "$1$/$2$/$3$",
          [
          date.day.format("%02d"),
          date.month.format("%02d"),
          date.year
          ]
       ); 
    }

    function saveToday() {
      var today     = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
      mLastRideDate = getToDay();

      //2 3 4 5 6 7  1
      //0 1 2 3 4 5 -1
      //0 1 2 3 4 5  6

      var j = today.day_of_week;
      j = j - 2;
      if (j<0) {
        j = 6;
      }
      
      var n = mDays.size();

      for (var i=0; i<n; i++) {
        if (mDays[i][j]==null) {
          mDays[i][j] = 0;
        }
        mDays[i][j] += mValue[i]-mCorrect[i];
        if (_usecorrection) {
          mCorrect[i] = mValue[i];
        }
      }
      saveDays();    
    }



    /******************************************************************
     * HELPERS 
     ******************************************************************/  
    function debug (s) {
      try {
        if (_debug) {
          System.println("WeekTimerApp: "+s);
        } 
        if (s.find(" error:")!=null) {
          if (_sound) {
            Attention.playTone(Attention.TONE_ERROR);
          }
          if (!_debug) {
            System.println("=== ERROR =================================================================");
            var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            var v = now.hour.format("%02d")+":"+now.min.format("%02d")+":"+now.sec.format("%02d");
            System.println(v);
            System.println(""+s);
            System.println("WeekTimerView: "+s);
            System.println("===========================================================================");
          }
        }
      } catch (ex) {
        System.println("debug error:"+ex.getErrorMessage());
      }
    }

    function trim (s) {
      var l = s.length();
      var n = l;
      var m = 0;
      var stop;

      stop = false;
      for (var i=0; i<l; i+=1) {
        if (!stop) {
          if (s.substring(i, i+1).equals(" ")) {
            m = i+1;
          } else {
            stop = true;
          }
        }
      }

      stop = false;
      for (var i=l-1; i>0; i-=1) {
        if (!stop) {
          if (s.substring(i, i+1).equals(" ")) {
            n = i;
          } else {
            stop = true;
          }
        }
      }  

      if (n>m) {
        return s.substring(m, n);  
      } else {
        return "";
      }
    }

    function stringReplace(str, oldString, newString) {
      var result = str;

      while (true) {
        var index = result.find(oldString);

        if (index != null) {
          var index2 = index+oldString.length();
          result = result.substring(0, index) + newString + result.substring(index2, result.length());
        }
        else {
          return result;
        }
      }

      return null;
    }

    /******************************************************************
     * DRAW HELPERS 
     ******************************************************************/  
    function setStdColor (dc) {
      if (getBackgroundColor() == Gfx.COLOR_BLACK) {
         dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      } else {
          dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
      }   
    }

    /******************************************************************
     * VALUES 
     ******************************************************************/       
    function drawArrows (dc) {
      dc.setPenWidth(1);
      dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);

      var w = 15;
      var h = 15;

      var wf = w/2;
      var hf = h/3;

      var x = 5;
      var y = 5;

      // Pijl naar links
      /*
      dc.drawLine (x    , y+h/2    , x+wf , y        );  
      dc.drawLine (x+wf , y        , x+wf , y+hf    );
      dc.drawLine (x+wf , y+hf     , x+w  , y+(hf)  );
      dc.drawLine (x+w  , y+(hf)   , x+w  , y+2*(hf));
      dc.drawLine (x+w  , y+2*(hf) , x+wf , y+2*(hf));
      dc.drawLine (x+wf , y+2*(hf) , x+wf , y+h      );
      dc.drawLine (x+wf , y+h      , x    , y+h/2    );
      */

      // pijl naar rechts
      x = mW - 20;
      y = mH - 20;

      dc.drawLine (x+w    , y+h/2    , x+w-wf , y        );  
      dc.drawLine ( x+w-wf , y       ,x+w-wf , y+hf    );
      dc.drawLine (x , y+hf     , x+w-wf  , y+(hf)  );
      dc.drawLine (x , y+(hf)   , x       , y+2*(hf));
      dc.drawLine (x+w-wf  , y+2*(hf)     , x , y+2*(hf));
      dc.drawLine (x+w-wf  , y+2*(hf), x+w-wf   , y+h     );
      dc.drawLine (x+w  , y+h/2      , x+w-wf    , y+h    );
    }

    function drawValues (dc) {
      try {

        var x = mW/2;
        var f = Gfx.FONT_SYSTEM_NUMBER_MEDIUM;
        var h = 0;
        var tot =0;
        var v = "";
        var wn = mWeekNumber;
        var xoffset = 0;

        setStdColor(dc);

        //
        // draw title
        //

        if ((mState == Toybox.Activity.TIMER_STATE_ON) || (mState == Toybox.Activity.TIMER_STATE_PAUSED))  {
          dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_DK_RED);
          h = dc.getTextDimensions("X", Gfx.FONT_GLANCE)[1];
          dc.fillRectangle(0, 0, mW, h+6);
          dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_DK_RED);
        }


        dc.drawText(x, YMARGING, Gfx.FONT_GLANCE, "WEEK "+wn+" TOT.", Gfx.TEXT_JUSTIFY_CENTER); 

        // compute value
        if (mCurrentSeries==0) {
          // km
          tot = Math.round((getTotal(mCurrentSeries)+mValue[mCurrentSeries]-mCorrect[mCurrentSeries])/1000);
          v = tot.format("%i");
        }

        if (mCurrentSeries==1) {
          // kcal
          tot = Math.round((getTotal(mCurrentSeries)+mValue[mCurrentSeries]-mCorrect[mCurrentSeries]));
          v = tot.format("%i");
        }

        if (mCurrentSeries==2) {
          // minuten
          tot = Math.round((getTotal(mCurrentSeries)+mValue[mCurrentSeries]-mCorrect[mCurrentSeries])/(60*1000));
          v = tot.format("%i");
        }

        if (tot>1000) { 
          v = v + "  ";
          xoffset = -40;
        }   

        //
        // value color
        //
        setStdColor(dc);
        if (mCurrentSeries==0) {
          // km
          if (tot>200) {
            dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT); 
          }
        }

        if (mCurrentSeries==1) {
          // kCal
          if (tot>5000) {
            dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT); 
          }
        }

        if (mCurrentSeries==2) {
          // tijd
          if (tot>8*60) {
            dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT); 
          }
        }

        //
        // draw value
        //
        h = dc.getTextDimensions("X", f)[1];
        dc.drawText(x, mH/2-h/2, f, v, Gfx.TEXT_JUSTIFY_CENTER); 

        var w = dc.getTextDimensions(v, f)[0];

        //
        // draw unit
        //
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);  
        if (mCurrentSeries==0) {
          dc.drawText(x+w/2+4+xoffset, mH/2+10, Gfx.FONT_SYSTEM_XTINY, "KM", Gfx.TEXT_JUSTIFY_LEFT);     
        }    
        if (mCurrentSeries==1) {
          dc.drawText(x+w/2+4+xoffset, mH/2+10, Gfx.FONT_SYSTEM_XTINY, "KCAL", Gfx.TEXT_JUSTIFY_LEFT);     
        }    
         if (mCurrentSeries==2) {
          dc.drawText(x+w/2+4+xoffset, mH/2+10, Gfx.FONT_SYSTEM_XTINY, "MIN", Gfx.TEXT_JUSTIFY_LEFT);     
        }    

        //
        // draw weekdays
        //
        if (mDays[0]!=null) {
          var n = mDays[0].size();
          v = " ";
          for (var i=0; i<n; i++) {
            var m = mDays[mCurrentSeries][i];
            if (m==null) {
              m = "_";
            } else {
              if (mCurrentSeries==0) {
                m = Math.round(m/1000).format("%i");
              }
              if (mCurrentSeries==1) {
                m = Math.round(m).format("%i");
              }
              if (mCurrentSeries==2) {
                m = Math.round(m/(60*1000)).format("%i");
              }
            }
            v = v + m + " ";
          }

          setStdColor(dc);
          f = Gfx.FONT_SYSTEM_MEDIUM;
          if (dc.getTextDimensions(v, f)[0]>mW) {
            f = Gfx.FONT_SYSTEM_TINY;
          }
          if (dc.getTextDimensions(v, f)[0]>mW) {
            f = Gfx.FONT_SYSTEM_XTINY;
          }          
          dc.drawText(x, mH/2+h/2, f, v, Gfx.TEXT_JUSTIFY_CENTER);  
        }
      } catch (ex) {
        debug("drawValues error "+ex.getErrorMessage());
      }
    }

    /******************************************************************
     * COMPUTE 
     ******************************************************************/  
    function compute(info) {
      try {  

        mSH = System.getDeviceSettings().screenHeight;
        mSW = System.getDeviceSettings().screenWidth;

        // km gereden
        mValue[0] = 0;
        if (info.elapsedDistance!=null) {
          mValue[0] = info.elapsedDistance;
        }

        // calorieen
        mValue[1] = 0;
        if (info.calories!=null) {
          mValue[1] = info.calories;
        }

        // tijd
        mValue[2] = 0;
        if (info.timerTime!=null) {
          mValue[2] = info.timerTime;
        }

        // correct the correction
        var n = mDays.size();
        for (var i=0; i<n; i++) {
          if (mValue[0]<mCorrect[0]) {
            mCorrect[0] = 0;
          }
        }

        mState = info.timerState;

      } catch (ex) {
          debug("Compute error: "+ex.getErrorMessage());
      }                  
    }
    
    /******************************************************************
     * Event handlers 
     ******************************************************************/  
    function getCorrections () {
      var n = mDays.size();
      for (var i=0; i<n; i++) {
        mCorrect[i] = mValue[i];
      }    
    }

    function onTimer() {
    }

    function onTimerLap() {   
      debug("onTimerLap");
    }   

    function onTimerPause() {     
      debug("onTimerPause");
    }   

    function onTimerReset() {     
      debug("onTimerReset");
    }   

    function onTimerResume() {     
      debug("onTimerResume");
    }   

    function onTimerStart() {  
      debug("onTimerStart");
      getCorrections();
      checkNewWeek();
    }   

    function onTimerStop() {     
      debug("onTimerStop");
      saveToday();
    }    

    function onShow() as Void {
      debug("onShow");
    }   

    function onHide() as Void {
      debug("onHide");
    }   

    /******************************************************************
     * On Update
     ******************************************************************/  
    function handleTouch() {
      try {
        if (GlobalTouched==1) {
          mCurrentSeries--;
        }
        if (GlobalTouched==2) {
          mCurrentSeries++;
        }
        if (mCurrentSeries>2) {
           mCurrentSeries = 0;
        }
        if (mCurrentSeries<0) {
           mCurrentSeries = 2;
        }        
         
        GlobalTouched = -1;
      } catch (ex) {
        GlobalTouched = -1;
        debug("handleTouch error: "+ex.getErrorMessage());
      }
    }

    function onUpdate(dc) { 
      try {  
        mW = dc.getWidth();
        mH = dc.getHeight();
        handleTouch() ;
        dc.setColor(getBackgroundColor(), getBackgroundColor());
        dc.clear();
        setStdColor(dc);
        try { 
          drawValues(dc);
          drawArrows(dc);
        } catch (ex) {
          debug("onUpdate draw error: "+ex.getErrorMessage());
        }    
       
      } catch (ex) {
        debug("onUpdate ALL error: "+ex.getErrorMessage());
     }
    }

}
