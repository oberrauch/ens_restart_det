function [obs, sim] = rerun_eval(experiments, params)
  arguments
    experiments
    params.figure_subfolder = './figures'
    params.time_start = NaN
    params.time_end = NaN
  end


  experiments = load_settings_aux(experiments);
  [obs, sim] = load_point_timeseries(experiments, ["hsnt", "hsnp", "swep", "rhop"], ...
    "date_start",  params.time_start, ...
    "date_end",  params.time_end,...
    "sim_var_list", ["hsnt", "swet"], ...
    "quality_check", true);


  %% Aggregate statistics
  figure_out_folder = fullfile(params.figure_subfolder);
  create_folder(figure_out_folder)
  plot_ts_elevationbands(sim, obs, experiments, figure_out_folder);
  stats_automatic_stations(sim, obs, experiments, figure_out_folder, ["hsnt", "swep"], ["hsnt", "swet"]);


end
