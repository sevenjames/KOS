// Execute Node Script
// "This short script can execute any maneuver node with 0.1 m/s dv precision."

// 2019 JAO
// adjustments to math and logic, more status prints, code cleanup

// Based on 2017 "Execute Node Script" in the KOS Tutorial.
// https://ksp-kos.github.io/KOS_DOC/tutorials/exenode.html

//==============================================================================

@LAZYGLOBAL OFF.
local clearance is 1.
local nd is 0. // the node
local max_acc is 0.
local burn_duration is 0.
local prep_duration is 0.
local node_eta is 0.
local burn_eta is 0.
local prep_eta is 0.
local tset is 0. // throttle set
local node_vec is 0. // initial node burn vector
local node_complete is FALSE.
local remove_node is FALSE.
local blanks is "          ".
local program_state is "".
local steering_state is "".
local throttle_state is "".
local printline is 2.

if hasnode = 0 {
	print "No maneuver node.".
	set clearance to 0.
}
if ship:availablethrust = 0 {
	print "Main engines offline.".
	set clearance to 0.
}
if clearance = 1 {
	executenode().
} else {
	print "Program abort".
}

function print_header {
	set printline to 2.
	print "EXECUTING MANEUVER NODE".
	print "=======================".
	print program_state at (2,printline). set printline to printline + 1.
	print steering_state at (2,printline). set printline to printline + 1.
	print throttle_state at (2,printline). set printline to printline + 1.
}

function print_data {
	set printline to 8.
	print "prep eta         : " + round(prep_eta,2) + blanks at (2,printline). set printline to printline + 1.
	print "prep duration    : " + round(prep_duration,2) + blanks at (2,printline). set printline to printline + 1.
	print "burn eta         : " + round(burn_eta,2) + blanks at (2,printline). set printline to printline + 1.
	print "burn duration    : " + round(burn_duration,2) + blanks at (2,printline). set printline to printline + 1.
	print "mass             : " + round(ship:mass,5) + blanks at (2,printline). set printline to printline + 1.
	print "availablethrust  : " + round(ship:availablethrust,5) + blanks at (2,printline). set printline to printline + 1.
	print "max_acc          : " + round(max_acc,5) + blanks at (2,printline). set printline to printline + 1.
	print "nd:deltav:mag    : " + round(nd:deltav:mag,5) + blanks at (2,printline). set printline to printline + 1.
	print "vdot             : " + round(vdot(node_vec, nd:deltav),5) + blanks at (2,printline). set printline to printline + 1.
	print "tset             : " + round(tset,5) + blanks at (2,printline). set printline to printline + 1.
}

function executenode {
	//set terminal:width to 50.//confirm preferred term size in game.
	//set terminal:height to 24.
	clearscreen.

	// get the next available maneuver node
	set nd to nextnode.

	// Crude calculation of estimated duration of burn. 
	set max_acc to (ship:availablethrust/ship:mass).
	set burn_duration to (nd:deltav:mag/max_acc).

	// prep time = 10s + 10s per ton, consider setting a 60s minimum <<<<<<<<<<<
	set prep_duration to (10 + 10*ship:mass).

	// calc times
	set node_eta to nd:eta.
	set burn_eta to (node_eta - burn_duration/2).
	set prep_eta to (burn_eta - prep_duration).

	// Wait for node.
	until nd:eta <= ((burn_duration/2) + prep_duration) {
		wait 1. // no need for fast calc while waiting for prep
	}

	// ############ insert timewarp stop here

	// save the initial node vector
	set node_vec to nd:deltav.
	
	// start turning ship to align with node
	sas off.
	lock steering to node_vec.
	until vang(node_vec, ship:facing:vector) < 0.25 {
		wait 0. // allow at least 1 physics tick to elapse.
	}

	// wait for burn time
	until nd:eta <= (burn_duration/2) {
		wait 0. // allow at least 1 physics tick to elapse.
	}

	// lock throttle
	lock throttle to tset.

	until node_complete {
		// recalculate current max_acceleration. this goes up as fuel is spent and ship mass goes down.
		set max_acc to (ship:availablethrust/ship:mass).

		// throttle control; adjusts based on remaining node dv
		set tset to min(nd:deltav:mag/max_acc, 1).

		// vdot of initial and current vectors is used to measure completeness of burn
		// negative value indicates maneuver overshoot. possible with high TWR.
		if vdot(node_vec, nd:deltav) < 0 {
			lock throttle to 0.
			set remove_node to False. // keep node for review
			break.
		}

		// finalize burn when remaining dv is very small
		if nd:deltav:mag < 1.0 {
			// burn until node vector starts to drift significantly from initial vector
			wait until vdot(node_vec, nd:deltav) < 0.5.
			lock throttle to 0.
			set remove_node to True.
			set node_complete to True.
		}
		wait 0. // allow at least 1 physics tick to elapse.
	}

	// cleanup
	if remove_node {remove nd.}
	set ship:control:pilotmainthrottle to 0.
	unlock steering.
	unlock throttle.
	wait 1.

}
