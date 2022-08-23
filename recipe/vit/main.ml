open Vega_lite

let build_from_csv model name fname =
  let csv_contents =
    In_channel.with_open_text ("data/" ^ model ^ "/" ^ fname) In_channel.input_all
  in
  let format_ = Data_format.make ~type_:`Csv () in
  Data.inline ~name ~format_ @@ `String csv_contents
;;

let eval_dashboard _name data =
  let encoding =
    Encoding.
      [ field `x ~name:"model" ~type_:`nominal ()
      ; field_repeat_var `y ~name:"row" ~type_:`quantitative ()
      ; field `xOffset ~name:"hw" ~type_:`nominal ()
      ; field `color ~name:"hw" ~type_:`nominal ()
      ]
  in
  let base_viz =
    Viz.make
      ~data
      ~mark:(Mark.bar ~opts:[ "tooltip", `Assoc [ "content", `String "data" ] ] ())
      ~encoding
      ()
  in
  Viz.repeat ~row:[ "acc"; "loss"; "elapsed_time" ] ~data:(Data.name "empty") base_viz
;;

let noise_dashboard _name data =
  let base_viz =
    Viz.make
      ~data
      ~mark:(Mark.line ())
      ~encoding:
        Encoding.
          [ field `x ~name:"layer" ~type_:`nominal ()
          ; field_repeat_var `y ~name:"row" ~type_:`quantitative ()
          ; field `color ~name:"model" ~type_:`nominal ()
          ]
      ()
  in
  Viz.repeat ~row:[ "mean"; "std" ] ~data:(Data.name "empty") base_viz
;;

let dashboard name =
  let eval_name = "eval_" ^ name in
  let layer_name = "layer_" ^ name in
  let eval_data = build_from_csv name eval_name "eval.csv" in
  let noise_data = build_from_csv name layer_name "layer.csv" in
  let eval_viz = eval_dashboard eval_name eval_data in
  let noise_viz = noise_dashboard layer_name noise_data in
  Viz.hconcat [ eval_viz; noise_viz ]
;;

let () =
  let name = "vit" in
  let dashboard = dashboard name in
  Viz.to_json_file dashboard ~file:(Common.output_dir ^ name ^ Common.json_ext);
  let spec = Viz.to_json_str dashboard in
  let html = Common.gen_html spec in
  Out_channel.with_open_text
    (Common.output_dir ^ name ^ Common.html_ext)
    (fun out_ch -> Out_channel.output_string out_ch html)
;;
