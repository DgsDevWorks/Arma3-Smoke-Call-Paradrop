/*
    TRIGGER SETTINGS

    VARIABLE NAME: SmokeCallParatroopers
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

    private _blufor_soldiers = ["B_medic_F", "B_Soldier_A_F", "B_Soldier_F", "B_Sharpshooter_F", "B_Soldier_LAT_F", "B_Soldier_AR_F", "B_Soldier_F", "B_Soldier_GL_F", "B_Soldier_F", "B_Soldier_SL_F"];
    private _opfor_soldiers = ["O_medic_F", "O_Soldier_A_F", "O_Soldier_F", "O_Sharpshooter_F", "O_Soldier_LAT_F", "O_Soldier_AR_F", "O_Soldier_F", "O_Soldier_GL_F", "O_Soldier_F", "O_Soldier_SL_F"];
    private _indep_soldiers = ["I_medic_F", "I_Soldier_A_F", "I_Soldier_F", "I_Sharpshooter_F", "I_Soldier_LAT_F", "I_Soldier_AR_F", "I_Soldier_F", "I_Soldier_GL_F", "I_Soldier_F", "I_Soldier_SL_F"];

    private _show_debug_messages = true;

    private _fnParatroopersJump = {
		params ["_unitClasses", "_aircraft", "_paraGroup", "_paraUnits"];

		{
			_unitClass = _x;
			_unit = _paraGroup createUnit [_unitClass, [0, 0, 0], [], 0, "NONE"];
            _unit disableCollisionWith _aircraft;
			_unit moveInCargo _aircraft;
            _unit leaveVehicle _aircraft;
            _paraUnits pushBack _unit;

			_unit setSkill 0.5;
			_unit setSpeedMode "FULL";
			_unit setCombatMode "RED";
            _unit setFormation "LINE";
			_unit setBehaviour "COMBAT";
			
            unassignVehicle _unit;
			moveOut _unit;
			
            [_aircraft, _unit] spawn {
                params ["_aircraft", "_unit"];
                
                if (alive _unit) then {
                    _parachute = createVehicle ["Steerable_Parachute_F", getPosATL _unit, [], 0, "NONE"];
                    _unit moveInDriver _parachute;
                };
            };

            sleep 1;
		} forEach _unitClasses;

		if (count _paraUnits > 0) then {
			_paraGroup selectLeader (_paraUnits select (count _paraUnits - 1));
		};
	};

    private _fnParatroopersObjective = {
        params ["_requester", "_paraGroup", "_paraUnits"];
		
		waitUntil {sleep 0.1; ({(surfaceIsWater getPos _x) || isTouchingGround _x || !alive _x} count _paraUnits) >= (count _paraUnits)};

		_objectiveWP = group (leader _paraGroup) addWaypoint [getPosATL _requester, -1];
        _objectiveWP setWaypointCompletionRadius 10;
		_objectiveWP setWaypointType "MOVE";

        [_requester, _paraGroup, _objectiveWP] spawn {
            params ["_requester", "_paraGroup", "_objectiveWP"];

            while {(alive _requester) && (leader _paraGroup != _requester)} do {
                _objectiveWP setWaypointPosition [getPosATL _requester, -1];

                if (leader _paraGroup distance _requester <= 25) exitWith {
                    _paraGroup selectLeader _requester;
                    deleteWaypoint _objectiveWP;
                };

                sleep 10;
            };
        };
    };

    private _fnCargoAircraft = {
		params ["_requester", "_dropZonePoint"];
		
		_blufor_aircraft = missionNamespace getVariable "_blufor_aircraft";
		_opfor_aircraft = missionNamespace getVariable "_opfor_aircraft";
		_indep_aircraft = missionNamespace getVariable "_indep_aircraft";
        _blufor_soldiers = missionNamespace getVariable "_blufor_soldiers";
        _opfor_soldiers = missionNamespace getVariable "_opfor_soldiers";
        _indep_soldiers = missionNamespace getVariable "_indep_soldiers";
		_show_debug_messages = missionNamespace getVariable "_show_debug_messages";
        _fnParatroopersJump = missionNamespace getVariable "_fnParatroopersJump";
        _fnParatroopersObjective = missionNamespace getVariable "_fnParatroopersObjective";
		_fnCargoAircraft = missionNamespace getVariable "_fnCargoAircraft";
		
        _unitClasses = "";
		_vehicleClass = "";
		_requesterSide = side _requester;
		_requesterFaction = faction _requester;
        
		if (side _requester == west) then {_vehicleClass = _blufor_aircraft; _unitClasses = _blufor_soldiers};
        if (side _requester == east) then {_vehicleClass = _opfor_aircraft; _unitClasses = _opfor_soldiers};
        if (side _requester == resistance) then {_vehicleClass = _indep_aircraft; _unitClasses = _indep_soldiers};
		
        _dropDistance = 300;
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

        _paraUnits = [];
        _paraGroup = createGroup (side _requester);
		
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
					[_unitClasses, _aircraft, _paraGroup, _paraUnits] spawn _fnParatroopersJump;
                    [_requester, _paraGroup, _paraUnits] spawn _fnParatroopersObjective;
					_dropComplete = true;
					hint format ["The CARGO AIRCRAFT drops the PARATROOPERS!"];
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
		
		deleteVehicle _dropZonePoint;
		deleteVehicle _spawnPoint;
		deleteVehicle _despawnPoint;

        deleteWaypoint _dropZoneWP;
        deleteWaypoint _despawnWP;
	};

    missionNamespace setVariable ["_blufor_aircraft", _blufor_aircraft];
	missionNamespace setVariable ["_opfor_aircraft", _opfor_aircraft];
	missionNamespace setVariable ["_indep_aircraft", _indep_aircraft];
    missionNamespace setVariable ["_blufor_soldiers", _blufor_soldiers];
    missionNamespace setVariable ["_opfor_soldiers", _opfor_soldiers];
    missionNamespace setVariable ["_indep_soldiers", _indep_soldiers];
	missionNamespace setVariable ["_show_debug_messages", _show_debug_messages];
	missionNamespace setVariable ["_fnParatroopersJump", _fnParatroopersJump];
    missionNamespace setVariable ["_fnParatroopersObjective", _fnParatroopersObjective];
	missionNamespace setVariable ["_fnCargoAircraft", _fnCargoAircraft];
	
	private _ehParatroopersDrop = addMissionEventHandler ["ProjectileCreated", {
		params ["_smokeGrenade"];
		
		_ammoClass = ["SmokeShellBlue", "G_40mm_SmokeBlue"];
		
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