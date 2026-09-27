#  Copyright 2026 Luis Teixeira
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

import gpio
import mqtt

INPUT_PIN = 22
OUTPUT_PIN = 21
VOL_PIN = 19
SONG_PIN = 18

EVENT_WAIT = 30000

sequence = [320,320,320,2080,400,320,1600,320,880,320,2480,240,3760,320,1760,320,1600,320,880,320,1760,400,320,240,3080,360,320,320,240,240,240,320,3040,320,320,320,320,640,320,320,320,400,1280,320,1360,320,320,720,320,320,1280,320,2000,320,320,320,320,720,320,1280,400,320,640,320,320,320,2000,320,320,640,320,400,560,320,400,4960,320,320,640,320,640,320,400,4880,320,640,400,320,640,320,320,320,6880,320,320,320,640,400,320,960,960,320,1040,320,640,640,320,320,320,320,320,1040,320,640,640,640,640,640,1680,320,640,640,640,720,320,320,320,320,320,320,320,320,2960,320,960,320,240,320,400,320,2880,320,1040,320,960,640,640,640,1040,320,320,320,3520,320,320,400,320,320,320,320,320,400,320,320,320,320,2320,320,640,320,720,640,320,320,2000,320,320,400,320,640,320,320,1040,320,640,320,1040,400,640,320,320,640,2320,640,320,400,2640,320,640,320,2720,320,640,320,2640,320,640,320,2640,400,640,320,320,3680,320,320,3680,320,320,3680,320]

bell_playing = 0

bell_topic = 'stat/doorbell/EVENT'

var last_event

def init()
    gpio.pin_mode(OUTPUT_PIN, gpio.OUTPUT_OPEN_DRAIN)
    gpio.pin_mode(INPUT_PIN, gpio.INPUT)
    gpio.pin_mode(VOL_PIN, gpio.OUTPUT_OPEN_DRAIN)
    gpio.pin_mode(SONG_PIN, gpio.OUTPUT_OPEN_DRAIN)
    gpio.digital_write(OUTPUT_PIN, 1)
    gpio.digital_write(VOL_PIN, 1)
    gpio.digital_write(SONG_PIN, 1)
end

def play_sequence()
    for interval : sequence
        gpio.digital_write(OUTPUT_PIN, 0)
        tasmota.delay_microseconds(interval)
        gpio.digital_write(OUTPUT_PIN, 1)
    end
end

def song()
    gpio.digital_write(SONG_PIN, 0)
    tasmota.set_timer(500, /-> gpio.digital_write(SONG_PIN, 1))
end

def vol()
    gpio.digital_write(VOL_PIN, 0)
    tasmota.set_timer(3000, /-> gpio.digital_write(VOL_PIN, 1))
end

def play()
    gpio.digital_write(VOL_PIN, 0)
    tasmota.set_timer(100, /-> gpio.digital_write(VOL_PIN, 1))
end

class bell_detector
  var last_event

  def fast_loop()
    var curr_time = tasmota.millis() 
    var delta_time = curr_time - last_event
    var bell_state = gpio.digital_read(INPUT_PIN)

    if bell_state == 0 && delta_time > EVENT_WAIT
        last_event = curr_time
        # TODO change event payload:
        mqtt.publish(bell_topic, "1")
    end
  end

  def init()
    last_event = tasmota.millis()
    tasmota.add_fast_loop(/-> self.fast_loop())
  end
end

tasmota.add_driver(bell_detector())                     # register driver
tasmota.add_fast_loop(/-> bell_detector.fast_loop()) 

init()
#play_sequence()
