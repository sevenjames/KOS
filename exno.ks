// Execute Node Script
// "This short script can execute any maneuver node with 0.1 m/s dv precision."

// 2019-06-12 JAO
// adjustments to math and logic, more status prints, code cleanup

// Based on 2017 "Execute Node Script" in the KOS Tutorial.
// https://ksp-kos.github.io/KOS_DOC/tutorials/exenode.html

if hasnode {

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

// print maneuver data
// print "Burn duration: " + round(burn_duration) + " seconds".
// print "Node in: " + round(node_eta) + " seconds".
// print "Burn in: " + round(burn_eta) + " seconds".
print "Maneuver Prep Duration: " + round(prep_duration) + " seconds".
print "Maneuver Prep in " + round(prep_eta) + " seconds".

// Wait for node.
print "Waiting for node...".
wait until nd:eta <= ((burn_duration/2) + prep_duration).

// ############ insert timewarp stop here

// start turning ship to align with node
sas off.
set np to nd:deltav.
lock steering to np.
print "Steering locked.".
print "Turning ship to align with node...".
wait until vang(np, ship:facing:vector) < 0.25.

// wait for burn time
print "Waiting until burn time...".
wait until nd:eta <= (burn_duration/2).

// lock throttle
set tset to 0.
lock throttle to tset.
print "Throttle locked.".

// save the initial node deltav vector
set dv0 to nd:deltav.

print "Executing burn...".
set done to False.
until done {
	// recalculate current max_acceleration
	set max_acc to (ship:availablethrust/ship:mass).

	// throttle control; adjusts based on remaining node dv
	set tset to min(nd:deltav:mag/max_acc, 1).

	// dot product of initial node vector and current node vector indicates "completeness" of maneuver.
	// negative value indicates maneuver overshoot. possible with high TWR.
	if vdot(dv0, nd:deltav) < 0 {
		print "Possible overshoot detected.".
		lock throttle to 0.
		print "Remaining dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
		print "Burn Complete.".
		print "Maneuver node retained for review.".
		set remove_node to False.
		break.
	}

	// finalize burn when remaining dv is very small
	if nd:deltav:mag < 1.0 {
		print "Remaining dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
		print "Finalizing burn...".
		// burn until node vector starts to drift significantly from initial vector
		wait until vdot(dv0, nd:deltav) < 0.5.

		lock throttle to 0.
		print "Remaining dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
		print "Burn Complete.".
		set remove_node to True.
		set done to True.
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

print "Maneuver Node Complete.".

}

else {
	print "Program abort: No maneuver node.".
}
