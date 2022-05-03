


//bandwidth of azimuth error that triggers a roll reversal
IF NOT (DEFINED az_err_band) {
	GLOBAL az_err_band IS 15.
}


//reference timestep value, type of integrator function and flag for logging
IF (DEFINED sim_settings) {
	UNSET sim_settings.
}
GLOBAL sim_settings IS LEXICON(
					"deltat",20,
					"integrator","rk3",
					"log",FALSE
	).


//simulation termination conditions
//set these to the values of altitude and velocity you would like to find yourself at 
//when disengaging entry guidance
//range bias should be a small positive value to ensure a good margin of error for ranging
IF NOT (DEFINED sim_end_conditions) {
	GLOBAL sim_end_conditions IS LEXICON(
							"altitude",15000,
							"surfvel",400,
							"range_bias",0
	).
}




