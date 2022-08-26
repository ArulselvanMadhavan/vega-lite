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
      ; field `xOffset ~name:"hardware" ~type_:`nominal ()
      ; field `color ~name:"hardware" ~type_:`nominal ()
      ]
  in
  let base_viz =
    Viz.make ~data ~mark:(Mark.bar ~opts:[ Common.tooltip ] ()) ~encoding ()
  in
  Viz.repeat
    ~row:[ "accuracy"; "loss"; "elapsed_time" ]
    ~data:(Data.name "empty")
    base_viz
;;

let acc_zoom name _data =
  let rule_viz =
    Viz.make
      ~data:(Data.name name)
      ~mark:(Mark.other ~type_:"rule" ())
      ~encoding:Encoding.[ datum_i `y 99; value_s `color "red" ]
      ()
  in
  let bar_viz =
    Viz.make
      ~data:(Data.name name)
      ~mark:(Mark.other ~type_:"bar" ~opts:[ Common.tooltip ] ())
      ~encoding:
        Encoding.
          [ field `x ~name:"model" ~type_:`nominal ()
          ; field `xOffset ~name:"hardware" ~type_:`nominal ()
          ; field
              `color
              ~name:"hardware"
              ~type_:`nominal
              ~opts:[ "legend", `Assoc [ "title", `Null ] ]
              ()
          ; field
              `y
              ~title:"% of FP32"
              ~name:"fp32Percent"
              ~type_:`quantitative
              ~scale:(`other (`Assoc [ "domainMin", `Int 90; "clamp", `Bool true ]))
              ()
          ]
      ()
  in
  Viz.layer [ rule_viz; bar_viz ]
;;

let noise_dashboard _name data =
  let base_viz =
    Viz.make
      ~width:(`int 400)
      ~title:(`string "Layerwise Noise Distribution")
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

let dashboard folder_name =
  let eval_data_name = "eval_" ^ folder_name in
  let layer_data_name = "layer_" ^ folder_name in
  let eval_data = build_from_csv folder_name eval_data_name "eval.csv" in
  let noise_data = build_from_csv folder_name layer_data_name "layer.csv" in
  let eval_viz = eval_dashboard eval_data_name eval_data in
  let noise_viz = noise_dashboard layer_data_name noise_data in
  let acc_zoom_viz = acc_zoom eval_data_name eval_data in
  Viz.hconcat
    ~title:
      (`obj
        { text = String.capitalize_ascii folder_name ^ " dashboard"
        ; color = "green"
        ; dy = -50
        ; font_size = 24
        ; anchor = "middle"
        })
    [ eval_viz; Viz.vconcat [ acc_zoom_viz; noise_viz ] ]
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
