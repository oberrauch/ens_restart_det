function f04_start_rerun(main_dir, common_settings, meteo_perturb_dir)
  % F04_START_RERUN reruns with the computed perturbations at stations
  %
  % This function performs a deterministic run at station level, using the 
  % "average" perturbations used by the PF for each individual station.
  % This serves as a baseline, answering the question: "Can we reproduce the
  % PF result with a deterministic run?!"
  %
  % The MAIN_DIR specifies the path to the main output directory.
  % Depending on settings (e.g. precipiation input), subdirectories will be
  % created within.
  %
  % All other relevant simulation settings can be specified in the
  % COMMON_SETTINGS struct, analogous to the default Simulation_Settings_PF.
  % They should be the same as in `f02_start_script`, hence the name!
  %
  % The path to the perturbations being used must be specified in
  % METEO_PERTURB_DIR, whereby also the subfolders for the precipitation input
  % source and the "averaging" method must be included (not ideal, I know!).
  
  arguments
    main_dir
    common_settings struct
    meteo_perturb_dir (1, 1) string {mustBeFolder}
  end

  % specify model output folder by concatenating the given main directory
  % with the selected precipitation input
  prcp_input_text = common_settings.prec_input_folder.split('\');
  prcp_input_text = char(prcp_input_text(end));
  if isempty(prcp_input_text)
    prcp_input_text = 'COSMO';
  end
  parent_root_directoy = fullfile(main_dir, prcp_input_text);
  create_folder(parent_root_directoy)

  % default settings
  settings = struct();
  settings.run_id = 0;
  settings.run_id_hn = -1;
  settings.operational = false;
%   settings.init_type = 'reinitialize';
%   settings.states_folder_reinit = fullfile(parent_root_directoy, 'rerun', 'OUTPUT_STAT', 'STATES');
  settings.geom = 'point';
  settings.silent = 0;
  % store in "PF_rerun" sub-directory
  settings.root_folder = fullfile(parent_root_directoy, 'rerun');

  % broadcast meteo perturbations
  settings.broadcast_meteo_pert = true;
  settings.meteo_perturb_dir = meteo_perturb_dir;
  settings.interp_radius_km = 35;
  settings.interp_min_stats = 3;
  settings.interp_z_scaling = 50;
  
  % THESE ARE THE IMPORTANT SETTING FOR THE RERUN/LOO EXPERIMENT
  settings.interp_exact_match = true;
  settings.interp_loo = false;
  
  settings = update_settings(settings, common_settings);

  run_FSMtimeloop(settings);

end
