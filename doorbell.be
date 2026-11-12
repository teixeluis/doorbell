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
import ULP

INPUT_PIN = 22
OUTPUT_PIN = 21
VOL_PIN = 19
SONG_PIN = 18
WAKE_PIN = 4

EVENT_WAIT = 30000
WAKE_PERIOD = 30000
DEEP_SLEEP_TIME = 20
ACTIVE_TIME = 2000
MELODY_TIME = 20000

# Wake-up causes:
WAKEUP_ULP = 6

sequence = [320,320,320,2080,400,320,1600,320,880,320,2480,240,3760,320,1760,320,1600,320,880,320,1760,400,320,240,3080,360,320,320,240,240,240,320,3040,320,320,320,320,640,320,320,320,400,1280,320,1360,320,320,720,320,320,1280,320,2000,320,320,320,320,720,320,1280,400,320,640,320,320,320,2000,320,320,640,320,400,560,320,400,4960,320,320,640,320,640,320,400,4880,320,640,400,320,640,320,320,320,6880,320,320,320,640,400,320,960,960,320,1040,320,640,640,320,320,320,320,320,1040,320,640,640,640,640,640,1680,320,640,640,640,720,320,320,320,320,320,320,320,320,2960,320,960,320,240,320,400,320,2880,320,1040,320,960,640,640,640,1040,320,320,320,3520,320,320,400,320,320,320,320,320,400,320,320,320,320,2320,320,640,320,720,640,320,320,2000,320,320,400,320,640,320,320,1040,320,640,320,1040,400,640,320,320,640,2320,640,320,400,2640,320,640,320,2720,320,640,320,2640,320,640,320,2640,400,640,320,320,3680,320,320,3680,320,320,3680,320]

BELL_TOPIC = 'stat/ovalesublime-doorbell/EVENT'

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
    tasmota.resp_cmnd_done()
end

def vol()
    gpio.digital_write(VOL_PIN, 0)
    tasmota.set_timer(3000, /-> gpio.digital_write(VOL_PIN, 1))
    tasmota.resp_cmnd_done()
end

def play()
    gpio.digital_write(VOL_PIN, 0)
    tasmota.set_timer(100, /-> gpio.digital_write(VOL_PIN, 1))
    tasmota.resp_cmnd_done()
end

class bell_detector
  def fast_loop()
    var curr_time = tasmota.millis() 
    var delta_time = curr_time - last_event
    var bell_state = gpio.digital_read(INPUT_PIN)

    if bell_state == 0 && delta_time > EVENT_WAIT
        last_event = curr_time
        mqtt.publish(BELL_TOPIC, "{\"event_type\": \"ringing\"}")
    end
  end

  def init()
    last_event = tasmota.millis()
    tasmota.add_fast_loop(/-> self.fast_loop())
  end
end

def deep_sleep()
    # Poll the input every 20 ms
    ULP.wake_period(0, WAKE_PERIOD)

    # Original ESP32: GPIO4 = RTC_GPIO10
    var io_num = ULP.gpio_init(WAKE_PIN, 0)

    # ULP FSM binary implementing GPIO edge detection
    var c = bytes().fromb64("dWxwAAwAzAAAABgAgwOAcg8AANA8AIBwEAAJggkBuC4wAMBwKAAAgAkB+C8PASByMADAcBAAQHIzA4ByDwAA0DMAAHAfAEByVABAgFMDgHJCA4ByDwAA0AsAAGgAAACwQwOAcg4AANAKAABycABAgBoAIHIOAABoAAAAsFMDgHJCA4ByDwAA0AsAAGgzA4ByDgAA0BoAAHIaAEByDgAAaGMDgHIOAADQGgAAcg4AAGhzA4ByDwAA0C8AIHC4AECAAAAAsDAAzCkQAEByuABAgAEAAJAAAACw")

    ULP.load(c)
    c = nil

    # Configure GPIO wake-up
    ULP.set_mem(50, 1)       # Expect rising edge
    ULP.set_mem(54, 0)       # Initial edge counter
    ULP.set_mem(55, 1)       # Wake after one edge
    ULP.set_mem(56, io_num)  # RTC GPIO number

    # Start ULP
    ULP.run()

    # Enter deep sleep and wake up every 5 mins:
    ULP.sleep(DEEP_SLEEP_TIME)
end

# Stay awaken for some time before going back to sleep:
def deep_sleep_now()
    tasmota.set_timer(ACTIVE_TIME, deep_sleep)
end

def on_mqtt_connected()
    if tasmota.wakeup_cause() == WAKEUP_ULP
        mqtt.publish(BELL_TOPIC, "{\"event_type\": \"ringing\"}")
    end
end

tasmota.add_cmd('BellPlay', play)
tasmota.add_cmd('BellVol', vol)
tasmota.add_cmd('BellSong', song)

tasmota.add_driver(bell_detector())
tasmota.add_fast_loop(/-> bell_detector.fast_loop()) 
tasmota.add_rule("MQTT#Connected", on_mqtt_connected)

init()

