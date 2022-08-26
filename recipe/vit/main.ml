open Vega_lite

let build_from_csv fname =
  let csv_contents =
    In_channel.with_open_text fname In_channel.input_all
  in
  let format_ = Data_format.make ~type_:`Csv () in
  Data.inline ~name:fname ~format_ @@ `String csv_contents
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
  let text_viz =
    Viz.make
      ~data:(Data.name name)
      ~mark:
        (Mark.other
           ~type_:"text"
           ~opts:
             [ "text", `String "99% threshold"
             ; "align", `String "right"
             ; "baseline", `String "middle"
             ; "x", `String "width"
             ; "dx", `Int 75
             ]
           ())
      ~encoding:Encoding.[ datum_f `y 99. ]
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
  Viz.layer [ rule_viz; text_viz; bar_viz ]
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


let eval_file_path = ref ""
let layer_file_path = ref ""
let out_dir = ref ""
let model_name = ref ""

let dashboard () =
  let eval_data = build_from_csv !eval_file_path in
  let noise_data = build_from_csv !layer_file_path in
  let eval_viz = eval_dashboard !eval_file_path eval_data in
  let noise_viz = noise_dashboard !layer_file_path noise_data in
  let acc_zoom_viz = acc_zoom !eval_file_path eval_data in
  Viz.hconcat
    ~title:
      (`obj
        { text = String.capitalize_ascii !model_name ^ " dashboard"
        ; color = "green"
        ; dy = -50
        ; font_size = 24
        ; anchor = "middle"
        })
    [ eval_viz; Viz.vconcat [ acc_zoom_viz; noise_viz ] ]
;;

let speclist =
  [ "-n", Arg.Set_string model_name, "Model Name"
  ; "-e", Arg.Set_string eval_file_path, "Path to eval_results.csv"
  ; "-l", Arg.Set_string layer_file_path, "Path to layer_results.csv"
  ; "-o", Arg.Set_string out_dir, "Output dir"
  ]
;;


let anon_fun doc = print_string doc

let usage_msg =
  "main.exe -n -e -l -o"
;;

let () =
  Arg.parse speclist anon_fun usage_msg;
  let dashboard = dashboard () in
  Viz.to_json_file dashboard ~file:( !out_dir ^ "/" ^ "dashboard" ^ Common.vl_json_ext);
  let spec = Viz.to_json_str dashboard in
  let html = Common.gen_html spec in
  Out_channel.with_open_text
    (!out_dir ^ "/" ^ "dashboard" ^ Common.html_ext)
    (fun out_ch -> Out_channel.output_string out_ch html)
