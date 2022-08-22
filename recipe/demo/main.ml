open Vega_lite

let build_from_csv name =
  let csv_contents = In_channel.with_open_text "data/ssd1200.csv" In_channel.input_all in
  let format_ = Data_format.make ~type_:`Csv () in
  Data.inline ~name ~format_ @@ `String csv_contents
;;

(* Default configs *)
let default_width = 600
let overview_height = 60
let layer_field = Encoding.field `x ~name:"layer" ~type_:`ordinal ~title:"Layer" ()
let mark_rule = Mark.other ~type_:"rule" ()

let brush_param =
  let x_interval = (Selection.interval ~opts:[ "encodings", `List [ `String "x" ] ]) () in
  Param.select ~name:"brush" x_interval
;;

let hover_param =
  let point_select = Selection.point ~on:`mouseover ~clear:`mouseup () in
  Param.select ~name:"hover" point_select
;;

let overview name =
  let mark = Mark.line () in
  let encoding =
    Encoding.
      [ field `facet ~name:"metric" ~type_:`ordinal ~opts:[ "columns", `Int 1 ] ()
      ; layer_field
      ; field `y ~name:"value" ~type_:`quantitative ()
      ]
  in
  Viz.make
    ~height:(`int overview_height)
    ~width:(`int default_width)
    ~title:"Overview of Layer wise noise stats"
    ~params:[ brush_param ]
    ~data:(Data.name name)
    ~mark
    ~encoding
    ()
;;

let detailed name filter_expr thold title =
  let circle_mark =
    Mark.circle ~opts:[ "tooltip", `Assoc [ "content", `String "data" ] ] ()
  in
  let filter_std = Transform.filter ~expr:filter_expr () in
  let scale_json = `Assoc [ "domain", `Assoc [ "param", `String "brush" ] ] in
  let x_encoding =
    Encoding.field `x ~name:"layer" ~type_:`ordinal ~scale:(`other scale_json) ()
  in
  let encoding =
    Encoding.[ x_encoding; field `y ~name:"value" ~type_:`quantitative ~title () ]
  in
  let circle_layer =
    Viz.make
      ~transform:[ filter_std ]
      ~data:(Data.name name)
      ~mark:circle_mark
      ~params:[ hover_param ]
      ~encoding
      ()
  in
  let rule_layer =
    Viz.make ~transform:[ filter_std ] ~data:(Data.name name) ~mark:mark_rule ~encoding ()
  in
  let t_circle_layer =
    Viz.make
      ~transform:
        [ filter_std
        ; Transform.filter ~expr:("datum.value >= " ^ Float.to_string thold) ()
        ]
      ~data:(Data.name name)
      ~mark:(Mark.circle ())
      ~encoding:(encoding @ [ Encoding.value_s `color "red" ])
      ()
  in
  let t_line_layer =
    Viz.make
      ~mark:(Mark.line ())
      ~data:(Data.name name)
      ~encoding:Encoding.[ x_encoding; datum_f `y thold ]
      ()
  in
  let t_text_layer =
    Viz.make
      ~mark:
        (Mark.other
           ~type_:"text"
           ~opts:
             [ "text", `String "Threshold"
             ; "align", `String "right"
             ; "baseline", `String "bottom"
             ; "x", `String "width"
             ; "dx", `Int (-2)
             ]
           ())
      ~data:(Data.name name)
      ~encoding:Encoding.[ datum_f `y thold ]
      ()
  in
  Viz.layer
    ~title:("Detailed View - " ^ title)
    ~width:(`int default_width)
    [ circle_layer; rule_layer; t_circle_layer; t_line_layer; t_text_layer ]
;;

let lift_data data =
  let empty_mark = Mark.line ~opts:[ "size", `Int 0 ] () in
  Viz.make ~data ~mark:empty_mark ~encoding:[] ()
;;

let std_dev_filter = "datum.metric=='std'"
let mean_filter = "datum.metric=='mean'"
let std_dev_thold = 0.05
let mean_thold = 0.005

let dashboard name data =
  Viz.vconcat
    [ lift_data data
    ; overview name
    ; detailed name std_dev_filter std_dev_thold "Std Dev"
    ; detailed name mean_filter mean_thold "Mean"
    ]
;;

let () =
  let name = "resnet18" in
  let data = build_from_csv name in
  let viz = dashboard name data in
  Viz.to_json_file viz ~file:(Common.output_dir ^ name ^ Common.json_ext);
  let spec = Viz.to_json_str viz in
  let html = Common.gen_html spec in
  Out_channel.with_open_text
    (Common.output_dir ^ name ^ Common.html_ext)
    (fun out_ch -> Out_channel.output_string out_ch html)
;;
