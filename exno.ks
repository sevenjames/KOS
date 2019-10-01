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
	executenode{}.
} else {
	print "Program abort".
}

function executenode {
	clearscreen.
	print "EXECUTING MANEUVER NODE".
	print "=======================".

	// get the next available maneuver node
	set nd to nextnode.

	// Crude calculation of estimated duration of burn. 
	set max_acc to (ship:availablethrust/ship:mass).
	set burn_duration to (nd:deltav:mag/max_acc).

	// original prep time (60s + burn_duration/2) feels wonk.
	// trying different calc for maneuver prep time: 10s + 10s per ton
	set prep_duration to (10 + 10*ship:mass).

	// calc times
	set node_eta to nd:eta.
	set burn_eta to (node_eta - burn_duration/2).
	set prep_eta to (burn_eta - prep_duration).

	print "Maneuver Prep Duration: " + round(prep_duration) + " seconds".
	print "Maneuver Prep in " + round(prep_eta) + " seconds".

	// Wait for node.
	print "Waiting for node...".
	wait until nd:eta <= ((burn_duration/2) + prep_duration).

	// ############ insert timewarp stop here

	// save the initial node vector
	set node_vec to nd:deltav.
	
	// start turning ship to align with node
	sas off.
	lock steering to node_vec.
	print "Steering locked.".
	print "Turning ship to align with node...".
	wait until vang(node_vec, ship:facing:vector) < 0.25.

	// wait for burn time
	print "Waiting until burn time...".
	wait until nd:eta <= (burn_duration/2).

	// lock throttle
	lock throttle to tset.
	print "Throttle locked.".

	print "Executing burn...".
	until node_complete {
		// realtime data printout
		set printline to 12.
		print "availablethrust  : " + round(ship:availablethrust,5) + blanks at (2,printline). set printline to printline + 1.
		print "mass             : " + round(ship:mass,5)            + blanks at (2,printline). set printline to printline + 1.
		print "max_acc          : " + round(max_acc,5)              + blanks at (2,printline). set printline to printline + 1.
		print "nd:deltav:mag    : " + round(nd:deltav:mag,5)        + blanks at (2,printline). set printline to printline + 1.
		print "tset             : " + round(tset,5)                 + blanks at (2,printline). set printline to printline + 1.
		print "vdot             : " + round(vdot(node_vec, nd:deltav),5) + blanks at (2,printline). set printline to printline + 1.

		// recalculate current max_acceleration. this goes up as fuel is spent and ship mass goes down.
		set max_acc to (ship:availablethrust/ship:mass).

		// throttle control; adjusts based on remaining node dv
		set tset to min(nd:deltav:mag/max_acc, 1).

		// dot product of initial node vector and current node vector indicates "completeness" of maneuver.
		// negative value indicates maneuver overshoot. possible with high TWR.
		if vdot(node_vec, nd:deltav) < 0 {
			print "Possible overshoot detected.".
			lock throttle to 0.
			print "Remaining dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(node_vec, nd:deltav),1).
			print "Burn Complete.".
			print "Maneuver node retained for review.".
			set remove_node to False.
			break.
		}

		// finalize burn when remaining dv is very small
		if nd:deltav:mag < 1.0 {
			print "Remaining dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(node_vec, nd:deltav),1).
			print "Finalizing burn...".
			// burn until node vector starts to drift significantly from initial vector
			wait until vdot(node_vec, nd:deltav) < 0.5.

			lock throttle to 0.
			print "Remaining dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(node_vec, nd:deltav),1).
			print "Burn Complete.".
			set remove_node to True.
			set node_complete to True.
		}
	}

	// cleanup
	if remove_node {
		print "Removing maneuver node...".
		remove nd.
	}

	print "Unlocking controls...".
	set ship:control:pilotmainthrottle to 0.
	unlock steering.
	unlock throttle.
	wait 1.

	print "MANEUVER NODE COMPLETE.".

}
