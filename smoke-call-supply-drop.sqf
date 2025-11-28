/*
    TRIGGER SETTINGS

    VARIABLE NAME: SmokeCallSupplyDrop
    TYPE: None
    ACTIVATION: Anybody
    ACTIVATION TYPE: Not Present
    REPEATABLE: No
	SERVER ONLY: No
	CONDITION: this
	INTERVAL: 0.5
*/

[] spawn {
    private _blufor_aircraft = "B_Heli_Transport_03_black_F";
    private _opfor_aircraft = "O_Heli_Transport_04_covered_F";
    private _indep_aircraft = "I_Heli_Transport_02_F";

    private _supply_crate = "C_IDAP_supplyCrate_F";

    private _show_debug_messages = true;

    private _fnSupplyCrateDrop = {
        params ["_aircraft", "_crateClass", "_dropZonePoint"];

		_crate = createVehicle [_crateClass, [0, 0, 0], [], 0, "CAN_COLLIDE"];
		_crate attachTo [_aircraft, [0, -5, -5]];
		_crate setPhysicsCollisionFlag false;
		_crate setDir (_crate getDir _dropZonePoint);
		_crate lockInventory true;
		_crate allowDamage false;
		detach _crate;

		_crate addAction [
			"<t color='#00CC00'>Open Arsenal</t>",
			{ ["Open", true] spawn BIS_fnc_arsenal; },
			[], 1, false, true, "",
			"(_this distance _target) < 15"
		];

		_chemlight = createVehicle ["Chemlight_yellow", position _crate, [], 0, "CAN_COLLIDE"];
		_chemlight attachTo [_crate, [0, 0, 0]];

        [_dropZonePoint, _crate] spawn {
			params ["_dropZonePoint", "_crate"];
			
			_markerName = format ["SupplyDrop_%1", floor (random 10000)];
			_marker = createMarker [_markerName, position _crate];
			_marker setMarkerText "Supply Drop";
			_marker setMarkerColor "ColorOrange";
			_marker setMarkerType "loc_rearm";
			
			_parachute = createVehicle ["B_parachute_02_F", position _crate, [], 0, "CAN_COLLIDE"];
			_parachute attachTo [_crate, [0, 0, 0]];
			_parachute setDir (_parachute getDir _dropZonePoint);
			_parachute setPhysicsCollisionFlag false;
			_parachute allowDamage false;
			
			sleep 3;
			
			detach _parachute;
			_crate attachTo [_parachute, [0, 0, 0]];
			_crate setDir (getDir _parachute);
			_crate setPhysicsCollisionFlag true;
			
			while {(getPos _crate select 2) >= 0.5} do {
				_speed = vectorMagnitude wind;
				_dir = _parachute getDir _dropZonePoint;
				_parachute setDir _dir;
				
				_parachute setVelocity [ 
					(sin _dir) * (_speed * 1.75),
					(cos _dir) * (_speed * 1.75),
					velocity _parachute select 2
				];
				
				_marker setMarkerPos (getPos _crate);
				sleep 0.05;
			};

			detach _crate;
            deleteVehicle _dropZonePoint;
		};
    };

    private _fnCargoAircraft = {
		params ["_requester", "_dropZonePoint"];
		
		_blufor_aircraft = missionNamespace getVariable "_blufor_aircraft";
		_opfor_aircraft = missionNamespace getVariable "_opfor_aircraft";
		_indep_aircraft = missionNamespace getVariable "_indep_aircraft";
        _supply_crate = missionNamespace getVariable "_supply_crate";
		_show_debug_messages = missionNamespace getVariable "_show_debug_messages";
        _fnSupplyCrateDrop = missionNamespace getVariable "_fnSupplyCrateDrop";
		_fnCargoAircraft = missionNamespace getVariable "_fnCargoAircraft";
		
		_vehicleClass = "";
        _crateClass = _supply_crate;
        
		if (side _requester == west) then {_vehicleClass = _blufor_aircraft};
        if (side _requester == east) then {_vehicleClass = _opfor_aircraft};
        if (side _requester == resistance) then {_vehicleClass = _indep_aircraft};
		
        _dropDistance = 200;
		_spawnHeight = 250;
		_spawnDistance = 2500;
		_angle = random 360;
		
		_spawnPos = (getPosATL _dropZonePoint) vectorAdd [sin _angle * _spawnDistance, cos _angle * _spawnDistance, 0];
		_spawnPoint = createVehicle ["Land_HelipadEmpty_F", [(_spawnPos select 0), (_spawnPos select 1), 0], [], 0, "NONE"];
		
		_aircraft = createVehicle [_vehicleClass, _spawnPos, [], 0, "FLY"];
		createVehicleCrew _aircraft;
		
        _aircraft setPosATL [(getPosATL _aircraft select 0), (getPosATL _aircraft select 1), (getPosATL _aircraft select 2) + _spawnHeight];
        _aircraft setDir (_spawnPos getDir _dropZonePoint);
        _aircraft animate ["CargoRamp_Open", 1];

		_despawnPos = (getPosATL _dropZonePoint) vectorAdd ((vectorNormalized ((getPosATL _dropZonePoint) vectorDiff (getPosATL _aircraft))) vectorMultiply _spawnDistance);
		_despawnPoint = createVehicle ["Land_HelipadEmpty_F", [(_despawnPos select 0), (_despawnPos select 1), 0], [], 0, "NONE"];
		
		_auxiliaryPos = (getPosATL _dropZonePoint) vectorAdd ((vectorNormalized ((getPosATL _dropZonePoint) vectorDiff (getPosATL _aircraft))) vectorMultiply (_spawnDistance * 2));
		_auxiliaryPoint = createVehicle ["Land_HelipadEmpty_F", [(_auxiliaryPos select 0), (_auxiliaryPos select 1), 0], [], 0, "NONE"];
		
        waitUntil {alive driver _aircraft};
		
		_despawnWP = [];
		_dropZoneWP = [];
        _auxiliaryWP = [];
		_dropComplete = false;
		
		while {alive driver _aircraft} do {
			_aircraft setFuel 1;
            _aircraft setVehicleAmmo 1;
            _aircraft flyInHeight [_spawnHeight, true];
			
			_aircraft setSkill 1;
            _aircraft setSpeedMode "FULL";
            _aircraft setCombatMode "BLUE";
            _aircraft setBehaviour "CARELESS";
			
			if (!(_dropComplete) && (alive _requester) && (_requester isKindOf "Man")) then {
				
				hint format [
					"The CARGO AIRCRAFT is moving to the DROP ZONE\nAircraft altitude: %1m\nDrop zone: %2m", 
					(getPosATL _aircraft select 2) toFixed 2, (_aircraft distance2D _dropZonePoint) toFixed 2
				];
				
				if ((_dropZoneWP isEqualTo []) && (_despawnWP isEqualTo [])) then {
				
					_dropZoneWP = group _aircraft addWaypoint [getPosATL _dropZonePoint, -1];
					_dropZoneWP setWaypointCompletionRadius 100;
					_dropZoneWP setWaypointType "MOVE";
					
					_despawnWP = group _aircraft addWaypoint [getPosATL _despawnPoint, -1];
					_despawnWP setWaypointCompletionRadius 100;
					_despawnWP setWaypointType "MOVE";
					
					_auxiliaryWP = group _aircraft addWaypoint [getPosATL _auxiliaryPoint, -1];
					_auxiliaryWP setWaypointCompletionRadius 100;
					_auxiliaryWP setWaypointType "MOVE";
				};
				
				if (_aircraft distance2D _dropZonePoint <= _dropDistance) then {
					[_aircraft, _crateClass, _dropZonePoint] spawn _fnSupplyCrateDrop;
					_dropComplete = true;
					hint format ["The CARGO AIRCRAFT drops the SUPPLY CRATE!"];
				};
			} else {
				
				if !(_despawnWP isEqualTo []) then {
				
					if (_aircraft distance2D _despawnPoint <= 100) then {
						{deleteVehicle _x} forEach crew _aircraft;
						deleteVehicle _aircraft;
                        deleteWaypoint _auxiliaryWP;
					};
				};
			};
			
			sleep 1;
		};
		
		deleteVehicle _spawnPoint;
		deleteVehicle _despawnPoint;

        deleteWaypoint _dropZoneWP;
        deleteWaypoint _despawnWP;
	};

    missionNamespace setVariable ["_blufor_aircraft", _blufor_aircraft];
	missionNamespace setVariable ["_opfor_aircraft", _opfor_aircraft];
	missionNamespace setVariable ["_indep_aircraft", _indep_aircraft];
    missionNamespace setVariable ["_supply_crate", _supply_crate];
	missionNamespace setVariable ["_show_debug_messages", _show_debug_messages];
	missionNamespace setVariable ["_fnSupplyCrateDrop", _fnSupplyCrateDrop];
	missionNamespace setVariable ["_fnCargoAircraft", _fnCargoAircraft];
	
	private _ehParatroopersDrop = addMissionEventHandler ["ProjectileCreated", {
		params ["_smokeGrenade"];
		
		_ammoClass = ["SmokeShellOrange", "G_40mm_SmokeOrange"];
		
		if (typeOf _smokeGrenade in _ammoClass) then {
		
			if !(_smokeGrenade getVariable ["Marked", false]) then {
				_smokeGrenade setVariable ["Marked", true, true];
		
				[_smokeGrenade, _fnCargoAircraft] spawn {
					params ["_smokeGrenade", "_fnCargoAircraft"];
					
					_originPos = getPosATL _smokeGrenade;
					_thrower = ((nearestObjects [_originPos, ["CAManBase"], 5]) select {_x isKindOf "Man" && alive _x}) param [0, objNull];
					
					waitUntil {
						sleep 0.1;
						(!alive _smokeGrenade) || ((getPosATL _smokeGrenade select 2) < 0.3 && (vectorMagnitude velocity _smokeGrenade) < 0.1);
					};
					
					_finalPos = getPosATL _smokeGrenade;
					_markedPoint = createVehicle ["Land_HelipadEmpty_F", _finalPos, [], 0, "NONE"];
					
					_fnCargoAircraft = missionNamespace getVariable "_fnCargoAircraft";
					[_thrower, _markedPoint] call _fnCargoAircraft;
				};
			};
		};
	}];
};