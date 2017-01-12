# Wunderground Weather - Original Script by (lily@disorg.net)
# International Weather script for Eggdrop bots. Displays in both F/C and MPH/KPH
# Will return weather from www.wunderground.com 
# Requires TCL8.0 or greater, has only been tested on Eggdrop 1.8.0

# You must ".chanset #channel +weather" for each chan you wish to use this in 
# Usage: !w <input> 
# Input can be <zip> <city, st> <city, country> <airport code> <pws> 
# To use PWS: !w pws:yourwundergroundpws

# VERSION 4.0 - output string rewrite 
# VERSION 4.2 - http::cleanup, agent string update
# VERSION 4.3 - Single tag change in mobile.wunderground source (first in 4-ish years).
# VERSION 4.4 - fixed no windm var bug. 
# VERSION 4.5 - Single tag change in mobile.wunderground source for forecast. 
# VERSION 4.6 - Made default scale configurable
# Edited Feb 01, 2014 - Kiely Allen- Removed Forecast (may tidy up output later and add it again), Added Barometer/Pressure (Rising & Falling), Added Windchill, Fixed Output Tidyness
# Edited Feb 04, 2014 - David Moore - Color Changing Temperature, Aliases, Don't Show Windchill If There Is None
# Edited Feb 09, 2014 - Kiely Allen/David Moore - Added Wind Gust, Cleaned Up Code, Fixed Multiple Choices Bug
# Edited Feb 10, 2014 - David Moore - Don't show windchill if $windcf/$windcc is <0.5F than $tempf/$tempc. Wind would often be 'calm' and windchill would show 0.1-0.5F±
# Edited Feb 13, 2014 - Kiely Allen/David Moore - Remove metric related config checks, all output includes both imperial and metric. Don't show windchill if windchill is higher than $tempf, windchills under 1F of $tempf are insignificant
# Edited Feb 14, 2014 - Kiely Allen - Removed custom !ws as it didn't work as exoected, (need to fix missing $windgm error)
# Edited Jun 12, 2014 - Kiely Allen - Fixed $color extending to all text after $tempf with \003 (no-color)

####################################################################

package require http
setudef flag weather

bind pub - !tempo pub_w 
set agent "Mozilla/5.0 (X11; Linux i686; rv:2.0.1) Gecko/20100101 Firefox/4.0.1"
proc pub_w {nick uhand handle chan input} {
  
  global botnick agent
  if {[llength $input]==0} {
    putquick "PRIVMSG $chan :Tu esqueceste de informar a cidade ou o CEP!"
  } else {
    set query "http://mobile.wunderground.com/cgi-bin/findweather/getForecast?brand=mobile&query="
    for { set index 0 } { $index<[llength $input] } { incr index } {
      set query "$query[lindex $input $index]"
      if {$index<[llength $input]-1} then {
        set query "$query+"
      }
    }
  }

  set http [::http::config -useragent $agent]    
  set http [::http::geturl $query]
  set html [::http::data $http]; ::http::cleanup $http
  regsub -all "\n" $html "" html
  regexp {City Not Found} $html - nf
  if {[info exists nf]==1} {
	putquick "PRIVMSG $chan :$input Não encontrado."
	return 0
  }

# // Checks if there are multiple choices for the city eg. "detroit" which has 6 entries     
  regexp {Place: Temperature} $html - mc
  if {[info exists mc]==1} {
    putquick "PRIVMSG $chan :Existem múltiplas entradas para $input. Tente refinar a busca adicionando o estado ou país."
    return 0
  }

  regexp {Observed at<b>(.*)</b> </td} $html - loc
  if {[info exists loc]==0} { 
	putquick "PRIVMSG $chan :Condições não disponíveis para $input. Tente refinar a busca adicionando o estado ou país."
    return 0
  }

  regexp {Updated: <b>(.*?) on} $html - updated
  regsub -all "\<.*?\>" $updated "" updated

  regexp {Updated: <b>(.*?)Visibility</td} $html - data
    
  regexp {Temperature</td>  <td>  <span class="nowrap"><b>(.*?)</b>&deg;F</span>  /  <span class="nowrap"><b>(.*?)</b>&deg;C</span>} $data - tempf tempc
  if {[info exists tempf]==0} { 
    putquick "PRIVMSG $chan : Meteorologia para $loc não está disponível no momento."
    return 0
  }

  regexp {Conditions</td><td><b>(.*?)</b></td>} $data - cond
  if {[info exists cond]==0} { 
    set cond "Desconhecida"
  }
 
 # // Wind Gust in MPH and KMH
  regexp {Wind Gust</td>\s+<td>\s+<span class="nowrap"><b>(.*?)</b>&nbsp;mph</span>\s+/\s+<span class="nowrap"><b>(.*?)</b>&nbsp;km/h</span>} $data - windgm windgk
# // Wind Chill in MPH and KMH   
  regexp {Windchill</td>  <td>  <span class="nowrap"><b>(.*?)</b>&deg;F</span>  /  <span class="nowrap"><b>(.*?)</b>&deg;C</span>} $data - windcf windcc
# // Pressure in inches and hPa   
  regexp {Pressure</td><td>  <span class="nowrap"><b>(.*?)</b>&nbsp;in</span>  /  <span class="nowrap"><b>(.*?)</b>&nbsp;hPa</span>  <b>(.*?)</b>} $data - presi presh rifa    
# // Humidity Percentage   
  regexp {Humidity</td><td><b>(.*?)</b>} $data - hum
# // Dew Point
#    regexp {Dew Point</td>\s+<td>\s+ <span class="nowrap"><b>(.*?)</b>&deg;F</span>\s+/\s+<span class="nowrap"><b>(.*?)</b>&deg;C</span>} $data - dewf dewc
  
  if {[info exists windgm]==0} {
     set windgm "0.0"
  }
  if {[info exists windgk]==0} {
     set windgk "0.0"
  } 

# // Wind Direction, Wind Speed. Reverse ${windm}/${windk} and ${windgm}/${windgk} if you want metric as priority
  regexp {Wind</td><td><b>(.*?)</b> at  <span class="nowrap"><b>(.*?)</b>&nbsp;mph</span>  /  <span class="nowrap"><b>(.*?)</b>&nbsp;km/h</span>} $data - windd windm windk
  if {[info exists windm]==0} {
    set windm "0"
  } 
  if {$windm==0} { 
    set windout "Calmo"
  } else {	
    set windout "$windd @ ${windk}km/h) com rajadas de até ${windgk}km/h"
  }
  
# // Fahrenheit Color Changing. You can change colors based on fahrenheit temperatures. IRC allows only 15 colors. See mIRC color chart.
proc color {temp} {
  if {$temp < 20} {
    set color "\00312"
  } elseif {$temp < 45} {
    set color "\00311"
  } elseif {$temp < 70} {
    set color "\00309"
  } elseif {$temp < 85} {
    set color "\00307"
  } elseif {$temp < 100} {
    set color "\00304"
  } else {
    set color "\00313"
  }
  return $color
}

# // Reverse ${tempf}/${tempc} and ${windcf}/${windcc} if you want metric as priority
  set colorf [color $tempf]
  if {(([info exists windcf]==1)&&(abs($tempf - $windcf) > 1.0))&&($tempf > $windcf)} {
    set colorw [color $windcf]
    putquick "PRIVMSG $chan :\00313$loc:\003 \002Temperatura:\002$colorf ${tempc}C\003 - \002Sensação térmica:\002$colorw ${windcc}C \00300- \002Umidade:\002 $hum - \002Vento:\002 $windout\- \002Condições:\002 $cond - \002Atualizado:\002 $updated"
  }  else {
    putquick "PRIVMSG $chan :\00313$loc:\003 \002Temperatura:\002$colorf ${tempc}C\003 - \002Umidade:\002 $hum - \002Vento:\002 $windout - \002Condições:\002 $cond - \002Atualizado:\002 $updated"
  }
}

putlog "Wunderground Weather Loaded"

#\002Dew Point:\002 ${dewf}F (${dewc}C)
