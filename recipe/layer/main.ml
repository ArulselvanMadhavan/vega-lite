open Vega_lite

let num_layers = 19

let write_tensor l_idx out_ch =
  let open Owl in
  let module N = Dense.Ndarray.D in
  let is_odd = l_idx = 15 in
  let l_idx = Float.of_int l_idx in
  let tensor = N.uniform ~a:0. ~b:1. [| 2; 4 |] in
  let tensor = if is_odd then N.scalar_mul 2. tensor else tensor in
  let col_values = Array.map Float.to_string @@ Arr.to_array tensor in
  let l_idx = Int.to_string @@ Int.of_float l_idx in
  let l_name = "layer_" ^ l_idx in
  Array.iter
    (fun elem ->
      Out_channel.output_string out_ch @@ l_idx ^ "," ^ l_name ^ "," ^ elem ^ "\n")
    col_values
;;

let write_header out_ch =
  Out_channel.output_string out_ch
  @@ String.concat "," [ "layer_id"; "layer_name"; "value" ];
  Out_channel.output_string out_ch "\n"
;;

let process_layer_data out_ch =
  let empty_arr = Array.make num_layers () in
  Array.iteri (fun idx _elem -> write_tensor idx out_ch) empty_arr
;;

let write_layers out_ch =
  write_header out_ch;
  process_layer_data out_ch
;;

let build_data () = Out_channel.with_open_text "output.csv" write_layers

let dashboard () =
  Viz.make
    ~data:(Data.url "output.csv")
    ~mark:(Mark.line ())
    ~encoding:
      Encoding.
        [ field `x ~name:"layer_id" ~type_:`quantitative ()
        ; field `y ~name:"value" ~type_:`quantitative ()
        ]
    ()
;;

let () =
  build_data ();
  let dashboard = dashboard () in
  let spec = Viz.to_json_str dashboard in
  let html = Common.gen_html spec in
  Out_channel.with_open_text "layer-dashboard.html" (fun out_ch ->
    Out_channel.output_string out_ch html)
;;
