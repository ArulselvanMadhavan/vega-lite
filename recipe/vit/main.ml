open Vega_lite

let build_from_csv name fname =
  let csv_contents =
    In_channel.with_open_text ("data/" ^ name ^ "/" ^ fname) In_channel.input_all
  in
  let format_ = Data_format.make ~type_:`Csv () in
  Data.inline ~name ~format_ @@ `String csv_contents
;;

let eval_dashboard data = Viz.make ~data ~mark:(Mark.line ()) ()

let () =
  let name = "vit" in
  let eval_data = build_from_csv name "eval.csv" in
  let eval_viz = eval_dashboard eval_data in
  Viz.to_json_file eval_viz ~file:(Common.output_dir ^ name ^ Common.json_ext);
  let spec = Viz.to_json_str eval_viz in
  let html = Common.gen_html spec in
  Out_channel.with_open_text
    (Common.output_dir ^ name ^ Common.html_ext)
    (fun out_ch -> Out_channel.output_string out_ch html)
;;
