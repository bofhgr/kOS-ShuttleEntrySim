

FUNCTION blank_simstate {
	PARAMETER ICs.

	
	RETURN 	LEXICON(
		"simtime",0,
		"position",ICS["position"],
		"velocity",ICS["velocity"],
		"surfvel",surfacevel(ICS["velocity"],ICS["position"]),
		"altitude",bodyalt(ICS["position"]),
		"latlong",vec2pos(ICS["position"]),//LATLNG(0,0),
		"aero",LEXICON()
	
	).

}


FUNCTION current_simstate {
	RETURN 	LEXICON(
		"simtime",0,
		"position",-SHIP:ORBIT:BODY:POSITION,
		"velocity",SHIP:VELOCITY:ORBIT,
		"surfvel",SHIP:VELOCITY:SURFACE,
		"altitude",SHIP:ORBIT:BODY:POSITION:MAG - BODY:RADIUS,
		"latlong",SHIP:GEOPOSITION,
		"aero",LEXICON()
	
	).


}




DEclare Function accel {
	Parameter pos.
	Parameter vel.
	Parameter attitude.
	
	 
	LOCAL surfvel IS vel - vcrs(BODY:angularvel, pos).
	LOCAL outlex IS aeroforce(pos, surfvel, attitude).
	
	LOCAL acceltot TO outlex["load"] + gravitacc(pos).
	return LIST(acceltot,outlex).

}

declare function gravitacc {
	parameter pos.
	return -BODY:mu * pos:normalized / pos:sqrmagnitude.
}

declare function aeroforce_ld {
	parameter pos.
	parameter surfvel.
	parameter attitude.
	
	LOCAL roll IS attitude[1].
	LOCAL aoa IS attitude[0].
	
	LOCAL out IS LEXICON(
						"load",v(0,0,0),
						"lift",0,
						"drag",0
						).
	
	LOCAL altt IS pos:mag-BODY:radius.
	
	LOCAL vesselfore IS SHIP:FACING:FOREVECTOR:NORMALIZED.
	LOCAL vesseltop IS SHIP:FACING:TOPVECTOR:NORMALIZED.
	LOCAL vesselright IS VCRS(vesseltop,vesselfore):NORMALIZED.
	
	LOCAL airspeedaoa IS surfvel:MAG*rodrigues(vesselfore,vesselright,aoa):NORMALIZED.
	
	LOCAL totalforce IS ADDONS:FAR:AEROFORCEAT(altt,airspeedaoa).
	
	
	
	//convert the aerodynamic force into the frame defined by the vessel orientation vectors
	//divide by the ship mass to get acceleration
	 LOCAL localforce IS V( VDOT(vesselright,totalforce) ,VDOT(vesseltop,totalforce)  , VDOT(vesselfore,totalforce) )/(ship:mass).
	 
	//build a frame of reference centered about the survace velocity and the local up direction
	LOCAL velforward IS surfvel:NORMALIZED.
	LOCAL velup IS pos:NORMALIZED.
	LOCAL velright IS VCRS( velup, velforward).
	IF (velright:MAG < 0.001) {
		SET velright TO VCRS( vesseltop, velforward).
		IF (velright:MAG < 0.001) {
			SET velright TO VCRS( vesselfore, velforward):NORMALIZED.
		}
		ELSE {
			SET velright TO velright:NORMALIZED.
		}
	}
	ELSE {
		SET velright TO velright:NORMALIZED.
	}
	SET velup TO VCRS( velforward, velright):NORMALIZED.
	
	//build the pedicted vessel orientation vectors using aoa and roll information
	LOCAL pred_vesseltop IS rodrigues(velup,velforward,-roll).
	LOCAL pred_vesselright IS VCRS(pred_vesseltop,velforward):NORMALIZED.
	LOCAL pred_vesselfore IS rodrigues(velforward,pred_vesselright,-aoa).
	SET pred_vesseltop TO rodrigues(pred_vesseltop,pred_vesselright,-aoa).
	

	
	//rotate the local force vector to the new frame
	SET out["load"] TO (pred_vesselright*localforce:X + pred_vesseltop*localforce:Y + pred_vesselfore*localforce:Z ).
	//compute lift asnd drag components
	
	SET out["drag"] TO -VDOT(totalforce,airspeedaoa:NORMALIZED).
	SET out["lift"] TO VDOT(VXCL(airspeedaoa:NORMALIZED,totalforce),vesseltop:NORMALIZED).
	

	RETURN out.
	
}

declare function aeroforce {
	parameter pos.
	parameter surfvel.
	parameter attitude.
	
	LOCAL roll IS attitude[1].
	LOCAL aoa IS attitude[0].
	
	LOCAL altt IS pos:mag-BODY:radius.
	
	LOCAL vesselfore IS SHIP:FACING:FOREVECTOR:NORMALIZED.
	LOCAL vesseltop IS SHIP:FACING:TOPVECTOR:NORMALIZED.
	LOCAL vesselright IS VCRS(vesseltop,vesselfore):NORMALIZED.
	
	LOCAL airspeedaoa IS surfvel:MAG*rodrigues(vesselfore,vesselright,aoa):NORMALIZED.
	
	LOCAL totalforce IS ADDONS:FAR:AEROFORCEAT(altt,airspeedaoa).
	
	
	
	//convert the aerodynamic force into the frame defined by the vessel orientation vectors
	//divide by the ship mass to get acceleration
	 LOCAL localforce IS V( VDOT(vesselright,totalforce) ,VDOT(vesseltop,totalforce)  , VDOT(vesselfore,totalforce) )/(ship:mass).
	 
	//build a frame of reference centered about the survace velocity and the local up direction
	LOCAL velforward IS surfvel:NORMALIZED.
	LOCAL velup IS pos:NORMALIZED.
	LOCAL velright IS VCRS( velup, velforward).
	IF (velright:MAG < 0.001) {
		SET velright TO VCRS( vesseltop, velforward).
		IF (velright:MAG < 0.001) {
			SET velright TO VCRS( vesselfore, velforward):NORMALIZED.
		}
		ELSE {
			SET velright TO velright:NORMALIZED.
		}
	}
	ELSE {
		SET velright TO velright:NORMALIZED.
	}
	SET velup TO VCRS( velforward, velright):NORMALIZED.
	
	//build the pedicted vessel orientation vectors using aoa and roll information
	LOCAL pred_vesseltop IS rodrigues(velup,velforward,-roll).
	LOCAL pred_vesselright IS VCRS(pred_vesseltop,velforward):NORMALIZED.
	LOCAL pred_vesselfore IS rodrigues(velforward,pred_vesselright,-aoa).
	SET pred_vesseltop TO rodrigues(pred_vesseltop,pred_vesselright,-aoa).


	//rotate the local force vector to the new frame
	RETURN LEXICON("load", (pred_vesselright*localforce:X + pred_vesseltop*localforce:Y + pred_vesselfore*localforce:Z )).
	
}



DECLARE FUNCTION rk2 {
	PARAMETER dt.
	PARAMETER state.
	PARAMETER attitude.
	
	LOCAL pos IS state["position"].
	LOCAL vel IS state["velocity"].
	
	set state["simtime"] to state["simtime"] + dt.
	
	LOCAL out IS LIST().

	//RK2
	LOCAL p1 IS pos.
	LOCAL v1 IS vel.
	SET out TO accel(p1, v1, attitude).
	LOCAL a1 IS out[0].
	SET state["aero"] TO out[1].
	 
	LOCAL  p2 IS  pos + 0.5 * v1 * dt.
	LOCAL  v2 IS vel + 0.5 * a1 * dt.
	SET out TO accel(p2, v2, attitude).
	LOCAL  a2 IS out[0].

	 
	SET pos TO pos + (dt) * (v2  ).
	SET vel TO vel + (dt) * (a2 ).
	
	SET state["position"] TO pos.
	SET state["velocity"] TO vel.
	
	RETURN state.

}


DECLARE FUNCTION rk3 {
	PARAMETER dt.
	PARAMETER state.
	PARAMETER attitude.
	
	LOCAL pos IS state["position"].
	LOCAL vel IS state["velocity"].
	
	set state["simtime"] to state["simtime"] + dt.
	
	LOCAL out IS LIST().
	
	//RK3
	LOCAL p1 IS pos.
	LOCAL v1 IS vel.
	SET out TO accel(p1, v1, attitude).
	LOCAL a1 IS out[0].
	SET state["aero"] TO out[1].
	 
	LOCAL  p2 IS  pos + 0.5 * v1 * dt.
	LOCAL  v2 IS vel + 0.5 * a1 * dt.
	SET out TO accel(p2, v2, attitude).
	LOCAL a2 IS out[0].
	 
	LOCAL  p3 IS pos + (2*v2 - v1) * dt.
	LOCAL  v3 IS vel + (2*a2 - a1) * dt.
	SET out TO accel(p3, v3, attitude).
	LOCAL a3 IS out[0].
	 
	 
	SET pos TO pos + (dt / 6) * (v1 + 4 * v2 + v3 ).
	SET vel TO vel + (dt / 6) * (a1 + 4 * a2 + a3).
	
	SET state["position"] TO pos.
	SET state["velocity"] TO vel.
	
	RETURN state.

}


DECLARE FUNCTION rk4 {
	PARAMETER dt.
	PARAMETER state.
	PARAMETER attitude.
	
	LOCAL pos IS state["position"].
	LOCAL vel IS state["velocity"].
	
	set state["simtime"] to state["simtime"] + dt.
	
	LOCAL out IS LIST().
	
	//RK4
	LOCAL p1 IS pos.
	LOCAL v1 IS vel.
	SET out TO accel(p1, v1, attitude).
	LOCAL a1 IS out[0].
	SET state["aero"] TO out[1].
	 
	LOCAL  p2 IS  pos + 0.5 * v1 * dt.
	LOCAL  v2 IS vel + 0.5 * a1 * dt.
	SET out TO accel(p2, v2, attitude).
	LOCAL a2 IS out[0].
	 
	LOCAL  p3 IS pos + 0.5 * v2 * dt.
	LOCAL  v3 IS vel + 0.5 * a2 * dt.
	SET out TO accel(p3, v3, attitude).
	LOCAL a3 IS out[0].
	 
	LOCAL  p4 IS pos + v3 * dt.
	LOCAL  v4 IS vel + a3 * dt.
	SET out TO accel(p4, v4, attitude).
	LOCAL a4 IS out[0].
	 
	SET pos TO pos + (dt / 6) * (v1 + 2 * v2 + 2 * v3 + v4).
	SET vel TO vel + (dt / 6) * (a1 + 2 * a2 + 2 * a3 + a4).

	
	SET state["position"] TO pos.
	SET state["velocity"] TO vel.
	
	RETURN state.

}









