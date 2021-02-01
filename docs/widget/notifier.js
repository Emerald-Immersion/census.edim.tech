"use strict";

function $(id) { return document.getElementById(id); }
function $$(selectors) { return document.querySelectorAll(selectors); }

var config = {
    me: 'player name or id',
    killAnnounce: [ 'oneLife', 'timeGap', 'base' ],
    headshotAnnounce: [ 'weapon name or id' ],
    rageQuitAnnounceSeconds: 60,
    outfit: {
        'outfit name or id': {
            baseCapture: [ 6200, 'Crown' ],
            baseDefend: true,
            killPlayer: [ 'player name or id' ]
        }
    },
    player: {
        'player name or id': {
            killPlayer: [ 'player name or id' ],
            deathPlayer: [ 'player name or id' ],
            killVehicle: [],
            deathVehicle: []
        }
    },
    world: {
        
    }
};

var socket = null;

function appNotifier() {
    if (window.location.hash) {
        var hash = window.location.hash;

        try {
            hash = hash.substring(1);
            config = JSON.parse(hash);
        } catch {
            config = JSON.parse(decodeURI(hash));
        }
    } else {
        config = {};
    }

    if (!config.me) {
        // TODO: tell user to setup hashtag variables in url
        return;
    }

    if (isNaN(Number(config.me))) {
        // TODO: Username lookup
        return;
    }

    if (!config.outfitBaseCapture) {
        // { "<outfitid>" : [ 'all', $facility_id, 'facility name?' ] }
    }
    
    if (!config.outfitBaseDefended) {
        // 
        // { "<outfitid>" : [ 'all', $facility_id, 'facility name?' ] }
    }
    
    if (!config.axilPoints) {

    }
}

function showNotification(image, heading, message, timeout, sound) {

}

function showIfRagequit(id) {
    // https://census.daybreakgames.com/get/ps2:v2/characters_online_status/?character_id=...



}

function setupSocket() {
	var server = new WebSocket('wss://push.planetside2.com/streaming?environment=ps2&service-id=s:example');

	server.onmessage = function (ev) {
		var data = JSON.parse(ev.data);

		if (!data.service || data.service != 'event') {
			return;
        }
        
        // TODO: Timer for heartbeat, reset timer on each

		// data.type == 'heartbeat' && data.online
		// data.type == 'serviceStateChanged'
		
		if (!data.type || data.type != 'serviceMessage') {
			return;
		}
		
		if (!data.payload || !data.payload.event_name) {
			return;
		}
		
		if (data.payload.event_name == 'Death') {
			
		} else if (data.payload.event_name == 'MetagameEvent') {
			
		} else if (data.payload.event_name == 'FacilityControl') {
			if (data.payload.new_faction_id == data.payload.old_faction_id) {
				// PlayerFacilityDefend
				return;
			}

			if (data.payload.facility_id == '6200' && data.payload.outfit_id == '37511594860086186') {
				// EDIM captured the Crown

			}
		}
	}

	server.onopen = function () {
		server.send(JSON.stringify({
			"service": "event",
			"action": "subscribe",
			"worlds": ["10"],
			"eventNames": ["FacilityControl", "MetagameEvent"]
		}));

		server.send(JSON.stringify({
			"service": "event",
			"action": "subscribe",
			"characters": ["5428059164954198113"],
			"eventNames": ["Death"]
		}));
	}

	server.onerror = function (err) {

	}

	return server;
}

this.addEventListener('load', appNotifier);