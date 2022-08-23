type json =
  [ `Int of int
  | `Float of float
  | `String of string
  | `Bool of bool
  | `Null
  | `List of json list
  | `Assoc of (string * json) list
  ]

(** Representation of values from raw data *)
module Data_format = struct
  type t =
    { type_ : [ `Json | `Csv | `Tsv | `Dsv of char ]
    ; parse : json option
    }

  let make ?(type_ = `Json) ?parse () : t = { type_; parse }

  let to_json self : json =
    let type_, others =
      match self.type_ with
      | `Json -> `String "json", []
      | `Csv -> `String "csv", []
      | `Tsv -> `String "tsv", []
      | `Dsv c -> `String "dsv", [ "delimiter", `String (Printf.sprintf "%c" c) ]
    in
    `Assoc
      (others
      @ [ "type", type_
        ; ( "parse"
          , match self.parse with
            | None -> `Null
            | Some j -> j )
        ])
  ;;
end

let[@inline] f2j f = `Float f
let[@inline] i2j x = `Int x
let[@inline] s2j s = `String s
let[@inline] assoc2j l = `Assoc l

module Values = struct
  type t =
    [ `String of string
    | `Array of json array
    | `Obj of json
    ]

  module Col = struct
    type t =
      | Float of float array
      | Int of int array
      | String of string array

    let floats a : t = Float a
    let ints a : t = Int a
    let strings a : t = String a

    let get_i_json a i =
      match a with
      | Float a -> `Float a.(i)
      | Int a -> `Int a.(i)
      | String a -> `String a.(i)
    ;;

    let len = function
      | Float a -> Array.length a
      | Int a -> Array.length a
      | String a -> Array.length a
    ;;
  end

  module Row = struct
    type t = (string * json) list

    let empty = []
    let int x v l : t = (x, `Int v) :: l
    let float x v l : t = (x, `Float v) :: l
    let string x v l : t = (x, `String v) :: l
    let to_json self = `Assoc self
  end

  let rows arr = `Array (Array.map Row.to_json arr)
  let rows_l l = rows @@ Array.of_list l

  let col1 c : t =
    `Array
      (match c with
       | Col.Float a -> Array.map f2j a
       | Col.Int a -> Array.map i2j a
       | Col.String a -> Array.map s2j a)
  ;;

  let col2 n1 c1 n2 c2 : t =
    if Col.len c1 <> Col.len c2 then invalid_arg "col2: incompatible lengths";
    `Array
      (Array.init (Col.len c1) (fun i ->
         `Assoc [ n1, Col.get_i_json c1 i; n2, Col.get_i_json c2 i ]))
  ;;

  let cols cols =
    match cols with
    | [] -> invalid_arg "Values.cols: empty list"
    | (_, c1) :: cols' ->
      let len = Col.len c1 in
      List.iter
        (fun (_, c) -> if Col.len c <> len then invalid_arg "cols: incompatible lengths")
        cols';
      `Array
        (Array.init len (fun i ->
           `Assoc (List.map (fun (n, c) -> n, Col.get_i_json c i) cols)))
  ;;

  let custom j : t = `Obj j

  let to_json : t -> json = function
    | `String _ as j -> j
    | `Array a -> `List (Array.to_list a)
    | `Obj j -> j
  ;;
end

(** Data to visualize *)
module Data = struct
  type inline =
    { name : string option
    ; format_ : Data_format.t option
    ; values : Values.t
    }

  type url =
    { url : string
    ; name : string option
    ; format_ : Data_format.t option
    }

  type t =
    [ `Url of url
    | `Inline of inline
    | `Name of string
    ]

  let url ?name ?format_ url : t = `Url { url; name; format_ }
  let name s : t = `Name s
  let inline ?name ?format_ values : t = `Inline { name; format_; values }

  let to_json : t -> json = function
    | `Url u ->
      `Assoc
        [ "url", `String u.url
        ; ( "name"
          , match u.name with
            | Some n -> `String n
            | None -> `Null )
        ; ( "format"
          , match u.format_ with
            | Some f -> Data_format.to_json f
            | None -> `Null )
        ]
    | `Inline i ->
      `Assoc
        [ "values", Values.to_json i.values
        ; ( "name"
          , match i.name with
            | Some n -> `String n
            | None -> `Null )
        ; ( "format"
          , match i.format_ with
            | Some f -> Data_format.to_json f
            | None -> `Null )
        ]
    | `Name s -> `Assoc [ "name", `String s ]
  ;;
end

module Mark = struct
  type t =
    { view : view
    ; opts : (string * json) list
    }

  and view =
    [ `Line
    | `Bar
    | `Point
    | `Tick
    | `Circle
    | `Errorband
    | `Other of string
    ]

  let mk_ ?(opts = []) view : t = { opts; view }
  let bar ?opts () : t = mk_ ?opts `Bar

  let line ?(opts = []) ?(point = false) () : t =
    let opts =
      [ (if point then [ "point", `Bool true ] else []); opts ] |> List.flatten
    in
    mk_ ~opts `Line
  ;;

  let tick ?opts () : t = mk_ ?opts `Tick
  let point ?opts () : t = mk_ ?opts `Point
  let circle ?opts () : t = mk_ ?opts `Circle

  let error_band ?(opts = []) ?extent () : t =
    let opts =
      match extent with
      | None -> opts
      | Some e ->
        let e =
          match e with
          | `ci -> "ci"
          | `stderr -> "stderr"
          | `stdev -> "stdev"
          | `iqr -> "iqr"
        in
        ("extent", `String e) :: opts
    in
    mk_ ~opts `Errorband
  ;;

  let other ?opts ~type_ () : t = mk_ ?opts (`Other type_)

  let to_json (self : t) : json =
    let view =
      `String
        (match self.view with
         | `Bar -> "bar"
         | `Line -> "line"
         | `Point -> "point"
         | `Circle -> "circle"
         | `Tick -> "tick"
         | `Errorband -> "errorband"
         | `Other s -> s)
    in
    match self.opts with
    | [] -> view
    | opts -> `Assoc (("type", view) :: opts)
  ;;
end

module Aggregate = struct
  type t =
    [ `mean
    | `sum
    | `product
    | `median
    | `min
    | `max
    | `count
    | `distinct
    | `argmin
    | `argmax
    | `values
    | `missing
    | `variance
    | `variancep
    | `stdev
    | `stdevp
    | `q1
    | `q3
    | `ci0
    | `ci1
    | `valid
    | `other of json
    ]

  let to_json : t -> json = function
    | `mean -> `String "mean"
    | `sum -> `String "sum"
    | `product -> `String "product"
    | `median -> `String "median"
    | `min -> `String "min"
    | `max -> `String "max"
    | `count -> `String "count"
    | `distinct -> `String "distinct"
    | `argmin -> `String "argmin"
    | `argmax -> `String "argmax"
    | `values -> `String "values"
    | `missing -> `String "missing"
    | `variance -> `String "variance"
    | `variancep -> `String "variancep"
    | `stdev -> `String "stdev"
    | `stdevp -> `String "stdevp"
    | `q1 -> `String "q1"
    | `q3 -> `String "q3"
    | `ci0 -> `String "ci0"
    | `ci1 -> `String "ci1"
    | `valid -> `String "valid"
    | `other j -> j
  ;;
end

module Transform = struct
  type t = (string * json) list

  (* TODO
  type aggregate_axis = json
     *)

  type window_axis = (string * json) list

  let window_axis ?(opts = []) ~op ~field ~as_ () : window_axis =
    [ "op", Aggregate.to_json op; "field", `String field; "as", `String as_ ] @ opts
  ;;

  let window_axis_other l : window_axis = l

  let window ?(opts = []) ?groupby ?frame ws : t =
    let ws = List.map assoc2j ws in
    List.flatten
      [ [ "window", `List ws ]
      ; (match groupby with
         | None -> []
         | Some l -> [ "groupby", `List (List.map s2j l) ])
      ; (match frame with
         | None -> []
         | Some (i, j) -> [ "frame", `List [ `Int i; `Int j ] ])
      ; opts
      ]
  ;;

  (* TODO
  let aggregate_axis ~op ~field ~as_ () : aggregate_axis =
    let op = match op with `mean -> `String "mean" in
    `Assoc ["op", op; "field", `String field; "as", `String as_]

  let aggregate l ~groupby () : t =
    "aggregate", `Assoc []
     *)

  let aggregate1 ?(opts = []) op : t = [ "aggregate", Aggregate.to_json op ] @ opts
  let filter ?(opts = []) ~expr () = [ "filter", `String expr ] @ opts
  let sample ?(opts = []) ~max () = [ "sample", `Assoc [ "sample", `Int max ] ] @ opts
  let other j : t = j
end

module Encoding = struct
  type channel =
    [ `x
    | `y
    | `x2
    | `y2
    | `xError
    | `yError
    | `xError2
    | `yError2
    | `xOffset
    | `yOffset
    | `theta
    | `theta2
    | `radius
    | `radius2
    | `longitude
    | `latitude
    | `longitude2
    | `latitude2
    | `angle
    | `color
    | `fill
    | `stroke
    | `opacity
    | `fillopacity
    | `strokeOpacity
    | `shape
    | `size
    | `strokeDash
    | `strokeWidth
    | `text
    | `tooltip
    | `href
    | `description
    | `detail
    | `order
    | `facet
    | `row
    | `column
    | `other of string
    ]

  let str_of_chan (c : channel) =
    match c with
    | `other s -> s
    | `x -> "x"
    | `y -> "y"
    | `x2 -> "x2"
    | `y2 -> "y2"
    | `xError -> "xError"
    | `yError -> "yError"
    | `xError2 -> "xError2"
    | `yError2 -> "yError2"
    | `xOffset -> "xOffset"
    | `yOffset -> "yOffset"
    | `theta -> "theta"
    | `theta2 -> "theta2"
    | `radius -> "radius"
    | `radius2 -> "radius2"
    | `longitude -> "longitude"
    | `latitude -> "latitude"
    | `longitude2 -> "longitude2"
    | `latitude2 -> "latitude2"
    | `angle -> "angle"
    | `color -> "color"
    | `fill -> "fill"
    | `stroke -> "stroke"
    | `opacity -> "opacity"
    | `fillopacity -> "fillopacity"
    | `strokeOpacity -> "strokeOpacity"
    | `shape -> "shape"
    | `size -> "size"
    | `strokeDash -> "strokeDash"
    | `strokeWidth -> "strokeWidth"
    | `text -> "text"
    | `tooltip -> "tooltip"
    | `href -> "href"
    | `description -> "description"
    | `detail -> "detail"
    | `order -> "order"
    | `facet -> "facet"
    | `row -> "row"
    | `column -> "column"
  ;;

  (** Type for a field.
      See https://vega.github.io/vega-lite/docs/encoding.html *)
  type field_type =
    [ `quantitative
    | `temporal
    | `ordinal
    | `nominal
    | `geojson
    | `other of json
    ]

  let json_of_field_type : field_type -> json = function
    | `quantitative -> `String "quantitative"
    | `temporal -> `String "temporal"
    | `ordinal -> `String "ordinal"
    | `nominal -> `String "nominal"
    | `geojson -> `String "geojson"
    | `other j -> j
  ;;

  type scale =
    [ `linear
    | `pow
    | `sqrt
    | `symlog
    | `log
    | `time
    | `utc
    | `ordinal
    | `band
    | `point
    | `bin_ordinal
    | `quantile
    | `quantize
    | `threshold
    | `other of json
    ]

  let json_of_scale : scale -> json =
    let mkty s = `Assoc [ "type", `String s ] in
    function
    | `linear -> mkty "linear"
    | `pow -> mkty "pow"
    | `sqrt -> mkty "sqrt"
    | `symlog -> mkty "symlog"
    | `log -> mkty "log"
    | `time -> mkty "time"
    | `utc -> mkty "utc"
    | `ordinal -> mkty "ordinal"
    | `band -> mkty "band"
    | `point -> mkty "point"
    | `bin_ordinal -> mkty "bin_ordinal"
    | `quantile -> mkty "quantile"
    | `quantize -> mkty "quantize"
    | `threshold -> mkty "threshold"
    | `other j -> j
  ;;

  type bin =
    [ `bool of bool
    | `binned (** already binned *)
    | `bin_with of (string * json) list (* "bin": true + fields *)
    | `other of json
    ]

  let json_of_bin : bin -> json = function
    | `bool b -> `Bool b
    | `binned -> `String "binned"
    | `bin_with fields -> `Assoc (("bin", `Bool true) :: fields)
    | `other j -> j
  ;;

  type aggregate = Aggregate.t

  (* TODO: timeUnit *)
  (* TODO: axis *)
  (* TODO: legend *)
  (* TODO: format *)
  (* TODO: stack *)
  (* TODO: sort *)
  (* TODO: condition *)

  type field_def =
    { field : [ `Field of string | `Repeat of string ]
    ; type_ : field_type option
    ; bin : bin
    ; aggregate : aggregate option
    ; title : string option
    ; scale : scale option
    ; sort :
        [ `ascending | `descending | `chan of [ `ascending | `descending ] * channel ]
        option
    ; transform : Transform.t list option
    ; opts : (string * json) list
    }

  type value = json
  type datum = json

  type definition =
    [ `Field of field_def
    | `Value of value
    | `Datum of datum
    ]

  type channel_def =
    { channel : channel
    ; def : definition
    }

  type t = channel_def list

  type 'a field_builder =
    channel
    -> ?bin:bin
    -> ?scale:scale
    -> ?title:string
    -> ?aggregate:aggregate
    -> ?sort:
         [ `ascending | `descending | `chan of [ `ascending | `descending ] * channel ]
    -> ?transform:Transform.t list
    -> ?opts:(string * json) list
    -> 'a

  let field_
    channel
    ?(bin = `bool false)
    ?scale
    ?title
    ?aggregate
    ?sort
    ?transform
    ?(opts = [])
    ~field
    ~type_
    ()
    : channel_def
    =
    { channel
    ; def = `Field { bin; title; aggregate; scale; field; type_; sort; transform; opts }
    }
  ;;

  let field channel ?bin ?scale ?title ?aggregate ?sort ?transform ?opts ~name ~type_ ()
    : channel_def
    =
    field_
      channel
      ?bin
      ?scale
      ?title
      ?aggregate
      ?sort
      ?transform
      ?opts
      ~field:(`Field name)
      ~type_:(Some type_)
      ()
  ;;

  let field_repeat_var
    channel
    ?bin
    ?scale
    ?title
    ?aggregate
    ?sort
    ?transform
    ?opts
    ~name
    ~type_
    ()
    : channel_def
    =
    field_
      channel
      ?bin
      ?scale
      ?title
      ?aggregate
      ?sort
      ?transform
      ?opts
      ~field:(`Repeat name)
      ~type_:(Some type_)
      ()
  ;;

  let field_repeat channel ?bin ?scale ?title ?aggregate ?sort ?transform ?opts ()
    : channel_def
    =
    field_
      channel
      ?bin
      ?scale
      ?title
      ?aggregate
      ?sort
      ?transform
      ?opts
      ~field:(`Repeat "repeat")
      ~type_:None
      ()
  ;;

  let datum channel d : channel_def = { channel; def = `Datum d }
  let datum_i c i = datum c (`Int i)
  let datum_f c f = datum c (`Float f)
  let datum_s c s = datum c (`String s)
  let value channel d : channel_def = { channel; def = `Value d }
  let value_i c i = value c (`Int i)
  let value_f c f = value c (`Float f)
  let value_s c s = value c (`String s)

  let json_of_chan_def (c : channel_def) : string * json =
    let def =
      match c.def with
      | `Value v -> `Assoc [ "value", v ]
      | `Datum v -> `Assoc [ "datum", v ]
      | `Field f ->
        let { field; type_; bin; scale; title; aggregate; sort; transform; opts } = f in
        let l =
          List.flatten
            [ [ ( "field"
                , match field with
                  | `Field s -> `String s
                  | `Repeat s -> `Assoc [ "repeat", `String s ] )
              ; "bin", json_of_bin bin
              ]
            ; (match scale with
               | None -> []
               | Some s -> [ "scale", json_of_scale s ])
            ; (match transform with
               | None -> []
               | Some l -> List.flatten l)
            ; (match type_ with
               | None -> []
               | Some t -> [ "type", json_of_field_type t ])
            ; (match sort with
               | None -> []
               | Some `ascending -> [ "sort ?transform", `String "ascending" ]
               | Some `descending -> [ "sort ?transform", `String "descending" ]
               | Some (`chan (`ascending, x)) ->
                 [ "sort ?transform", `String (str_of_chan x) ]
               | Some (`chan (`descending, x)) ->
                 [ "sort ?transform", `String ("-" ^ str_of_chan x) ])
            ; (match title with
               | None -> []
               | Some s -> [ "title", `String s ])
            ; (match aggregate with
               | None -> []
               | Some s -> [ "aggregate", Aggregate.to_json s ])
            ; opts
            ]
        in
        `Assoc l
    in
    let c = str_of_chan c.channel in
    c, def
  ;;

  let to_json (self : t) : json =
    let l = List.map json_of_chan_def self in
    `Assoc l
  ;;
end

module Input = struct
  type t =
    | Range of
        { min : int
        ; max : int
        ; step : int
        }
    | Select of json list
    | Checkbox
    | Radio of json list

  let range ~min ~max ?(step = 1) () : t = Range { min; max; step }
  let select l = Select l
  let select_str l = select (List.map s2j l)
  let checkbox = Checkbox
  let radio l = Radio (List.map s2j l)

  let to_json = function
    | Range { min; max; step } ->
      `Assoc
        [ "type", `String "range"; "min", `Int min; "max", `Int max; "step", `Int step ]
    | Select l -> `Assoc [ "type", `String "select"; "options", `List (`Null :: l) ]
    | Checkbox -> `Assoc [ "type", `String "checkbox" ]
    | Radio l -> `Assoc [ "type", `String "radio"; "options", `List l ]
  ;;
end

module Selection = struct
  type view =
    | Point
    | Interval

  type t =
    { on : [ `mouseover ] option
    ; clear : [ `mouseup ] option
    ; fields : string list option
    ; opts : (string * json) list
    ; view : view
    }

  type 'a with_opts =
    ?on:[ `mouseover ]
    -> ?clear:[ `mouseup ]
    -> ?fields:string list
    -> ?opts:(string * json) list
    -> 'a

  let mk ?on ?clear ?fields ?(opts = []) view : t = { on; clear; fields; view; opts }
  let point ?on ?clear ?fields ?opts () : t = mk ?on ?clear ?fields ?opts Point
  let interval ?on ?clear ?fields ?opts () : t = mk ?on ?clear ?fields ?opts Interval

  let to_json { on; clear; fields; view; opts } =
    let ty =
      match view with
      | Point -> "point"
      | Interval -> "interval"
    in
    let l =
      [ [ "type", `String ty ]
      ; (match on with
         | None -> []
         | Some `mouseover -> [ "on", `String "mouseover" ])
      ; (match clear with
         | None -> []
         | Some `mouseup -> [ "clear", `String "mouseup" ])
      ; (match fields with
         | None -> []
         | Some l -> [ "fields", `List (List.map s2j l) ])
      ; opts
      ]
      |> List.flatten
    in
    `Assoc l
  ;;
end

(** Parameters.

    Parameters provide dynamic behavior based on user input (for example,
    selection).

    https://vega.github.io/vega-lite/docs/parameter.html *)
module Param = struct
  type t =
    { name : string
    ; value : json option
    ; bind : [ `Input of Input.t | `Inputs of (string * Input.t) list | `Scales ] option
    ; select : Selection.t option
    }

  let input ~name ?value input : t =
    { name; value; bind = Some (`Input input); select = None }
  ;;

  let select ~name ?value ?bind ?bind_by_name sel : t =
    let bind =
      match bind, bind_by_name with
      | Some _, Some _ -> invalid_arg "Param.select: bind and bind_by_name are exclusive"
      | Some i, None -> Some (`Input i)
      | None, Some l -> Some (`Inputs l)
      | None, None -> None
    in
    { name; value; select = Some sel; bind }
  ;;

  let bind_scales ?(name = "grid") () : t =
    { name; value = None; select = Some (Selection.interval ()); bind = Some `Scales }
  ;;

  let to_json { name; value; bind; select } : json =
    let sel_pair =
      match select with
      | None -> []
      | Some sel -> [ "select", Selection.to_json sel ]
    and bind_pair =
      match bind with
      | Some (`Input i) -> [ "bind", Input.to_json i ]
      | Some (`Inputs l) ->
        [ "bind", `Assoc (List.map (fun (s, i) -> s, Input.to_json i) l) ]
      | Some `Scales -> [ "bind", `String "scales" ]
      | None -> []
    in
    let l =
      List.flatten
        [ [ "name", `String name ]
        ; sel_pair
        ; bind_pair
        ; (match value with
           | None -> []
           | Some v -> [ "value", v ])
        ]
    in
    `Assoc l
  ;;
end

module Config = struct
  type t = json

  let json j : t = j
  let to_json j = j
end

module Viz = struct
  type repeat_binding =
    { var : string
    ; values : json list
    }

  type repeat_spec =
    | R_simple of json list
    | R_full of
        { bind : repeat_binding list option
        ; column : string list option
        ; row : string list option
        ; layer : string list option
        }

  type t =
    { config : Config.t option
    ; width : [ `container | `int of int ] option
    ; height : [ `container | `int of int ] option
    ; title : string option
    ; params : Param.t list option
    ; view : view
    }

  and view =
    | Simple of
        { data : Data.t option
        ; mark : Mark.t
        ; transform : Transform.t list option
        ; encoding : Encoding.t option
        }
    | Layer of t list
    | Hconcat of t list
    | Vconcat of t list
    | Concat of
        { concat : t list
        ; columns : int
        }
    | Repeat of
        { data : Data.t
        ; repeat : repeat_spec
        ; spec : t
        }

  (** With options *)
  type 'a with_config =
    ?width:[ `container | `int of int ]
    -> ?height:[ `container | `int of int ]
    -> ?title:string
    -> ?config:Config.t
    -> ?params:Param.t list
    -> 'a

  let bind ~var l : repeat_binding = { var; values = l }
  let bind_i ~var l = bind ~var (List.map i2j l)
  let bind_f ~var l = bind ~var (List.map f2j l)
  let bind_s ~var l = bind ~var (List.map s2j l)

  let mk ?width ?height ?title ?config ?params view : t =
    { width; height; config; title; params; view }
  ;;

  let repeat ?width ?height ?title ?config ?params ?column ?row ?layer ?bind ~data spec
    : t
    =
    let is_none = function
      | None -> true
      | Some _ -> false
    in
    if is_none column && is_none row && is_none layer && is_none bind
    then invalid_arg "Viz.repeat: at least one repeating element has to be specified";
    let repeat = R_full { bind; column; row; layer } in
    mk ?width ?height ?title ?config ?params @@ Repeat { spec; repeat; data }
  ;;

  let repeat_simple ?width ?height ?title ?config ?params ~repeat:l ~data spec : t =
    let l = List.map (fun s -> `String s) l in
    let repeat = R_simple l in
    mk ?width ?height ?title ?config ?params @@ Repeat { spec; repeat; data }
  ;;

  let layer ?width ?height ?title ?config ?params l : t =
    mk ?width ?height ?config ?title ?params @@ Layer l
  ;;

  let hconcat ?width ?height ?title ?config ?params l =
    mk ?width ?height ?title ?config ?params @@ Hconcat l
  ;;

  let vconcat ?width ?height ?title ?config ?params l =
    mk ?width ?height ?title ?config ?params @@ Vconcat l
  ;;

  let concat ?width ?height ?title ?config ?params ~columns l : t =
    mk ?width ?height ?config ?title ?params @@ Concat { concat = l; columns }
  ;;

  let make ?width ?height ?title ?config ?params ~data ~mark ?transform ?encoding () : t =
    mk ?width ?height ?title ?config ?params
    @@ Simple { data = Some data; mark; transform; encoding }
  ;;

  let json_of_repeat (r : repeat_spec) : json =
    match r with
    | R_simple l -> `Assoc [ "repeat", `List l ]
    | R_full { column; row; layer; bind } ->
      let js_binding (r : repeat_binding) : _ * json = r.var, `List r.values in
      let js_strl name = function
        | None -> []
        | Some l -> [ name, `List (List.map s2j l) ]
      in
      let l =
        List.flatten
          [ js_strl "column" column
          ; js_strl "row" row
          ; js_strl "layer" layer
          ; (match bind with
             | None -> []
             | Some l -> List.map js_binding l)
          ]
      in
      `Assoc l
  ;;

  let rec to_json_assoc (self : t) : (string * json) list =
    let { width; height; params; config; title; view } = self in
    let conf =
      List.flatten
        [ (match width with
           | Some `container -> [ "width", `String "container" ]
           | Some (`int i) -> [ "width", `Int i ]
           | None -> [])
        ; (match height with
           | Some `container -> [ "height", `String "container" ]
           | Some (`int i) -> [ "height", `Int i ]
           | None -> [])
        ; (match config with
           | None -> []
           | Some j -> [ "config", j ])
        ; (match title with
           | None -> []
           | Some s -> [ "title", `String s ])
        ; (match params with
           | None -> []
           | Some p -> [ "params", `List (List.map Param.to_json p) ])
        ]
    in
    let rest =
      match view with
      | Simple { mark; data; transform; encoding } ->
        List.flatten
          [ [ "mark", Mark.to_json mark ]
          ; (match transform with
             | None -> []
             | Some l ->
               let l = List.map (fun l -> `Assoc l) l in
               [ "transform", `List l ])
          ; (match encoding with
             | None -> []
             | Some e -> [ "encoding", Encoding.to_json e ])
          ; (match data with
             | None -> []
             | Some d -> [ "data", Data.to_json d ])
          ]
      | Layer l -> [ "layer", `List (List.map to_json_sub l) ]
      | Hconcat l -> [ "hconcat", `List (List.map to_json_sub l) ]
      | Vconcat l -> [ "vconcat", `List (List.map to_json_sub l) ]
      | Concat { concat = l; columns } ->
        [ "concat", `List (List.map to_json_sub l); "columns", `Int columns ]
      | Repeat { data; repeat; spec } ->
        [ "data", Data.to_json data
        ; "repeat", json_of_repeat repeat
        ; "spec", to_json_sub spec
        ]
    in
    List.rev_append conf rest

  and to_json_sub self : json = `Assoc (to_json_assoc self)

  let to_json self : json =
    let l = to_json_assoc self in
    let l =
      [ "$schema", `String "https://vega.github.io/schema/vega-lite/v5.json" ] @ l
    in
    `Assoc l
  ;;

  let to_json_str self = Yojson.Basic.pretty_to_string @@ to_json self

  let to_json_file self ~file =
    let j = to_json self in
    Yojson.Basic.to_file file j
  ;;
end

(* check compat with yojson *)
let () =
  let j : json = `Null in
  let _j2 : Yojson.Basic.t = j in
  ()
;;
