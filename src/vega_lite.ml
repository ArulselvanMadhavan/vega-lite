
type json = [
  | `Int of int
  | `Float of float
  | `String of string
  | `Bool of bool
  | `Null
  | `List of json list
  | `Assoc of (string * json) list
]

(** Representation of values from raw data *)
module Data_format = struct
  type t = {
    type_ : [`Json | `Csv | `Tsv | `Dsv of char];
    parse: json option;
  }

  let make ?(type_=`Json) ?parse () : t = {type_; parse}
  let to_json self : json =
    let type_, others =
      match self.type_ with
      | `Json -> `String "json", []
      | `Csv -> `String "csv", []
      | `Tsv -> `String "tsv", []
      | `Dsv c -> `String "dsv", ["delimiter", `String (Printf.sprintf "%c" c)]
    in
    `Assoc (others @ [
      "type", type_;
      "parse", (match self.parse with None -> `Null | Some j -> j);
    ])
end

module Values = struct
  type t = [
    | `String of string
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

    let get_i_json a i = match a with
      | Float a -> `Float a.(i)
      | Int a -> `Int a.(i)
      | String a -> `String a.(i)

    let len = function
      | Float a -> Array.length a
      | Int a -> Array.length a
      | String a -> Array.length a
  end

  let[@inline] f2j f = `Float f
  let[@inline] i2j x = `Int x
  let[@inline] s2j s = `String s

  let col1 c : t =
    `Array (
      match c with
      | Col.Float a -> Array.map f2j a
      | Col.Int a -> Array.map i2j a
      | Col.String a -> Array.map s2j a
    )

  let col2 n1 c1 n2 c2 : t =
    if Col.len c1 <> Col.len c2 then invalid_arg "col2: incompatible lengths";
    `Array (
      Array.init (Col.len c1)
        (fun i -> `Assoc [
             n1, Col.get_i_json c1 i;
             n2, Col.get_i_json c2 i;
           ])
    )

  let cols cols =
    match cols with
    | [] -> invalid_arg "Values.cols: empty list"
    | (_,c1) :: cols' ->
      let len = Col.len c1 in
      List.iter
        (fun (_,c) -> if Col.len c <> len then invalid_arg "cols: incompatible lengths")
        cols';
      `Array (
        Array.init len
          (fun i ->
             `Assoc (List.map (fun (n,c) -> n, Col.get_i_json c i) cols))
      )

  let custom j : t = `Obj j

  let to_json : t -> json = function
    | `String _ as j -> j
    | `Array a -> `List (Array.to_list a)
    | `Obj j -> j
end

(** Data to visualize *)
module Data = struct
  type inline = {
    name: string option;
    format_: Data_format.t option;
    values: Values.t;
  }

  type url = {
    url: string;
    name: string option;
    format_ : Data_format.t option;
  }

  type t = [
    | `Url of url
    | `Inline of inline
    | `Name of string
  ]

  let url ?name ?format_ url : t = `Url {url; name; format_}
  let name s : t = `Name s
  let inline ?name ?format_ values : t =
    `Inline {name; format_; values}

  let to_json : t -> json = function
    | `Url u ->
      `Assoc [
        "url", `String u.url;
        "name", (match u.name with Some n -> `String n | None -> `Null);
        "format", (match u.format_ with Some f -> Data_format.to_json f | None -> `Null);
      ]
    | `Inline i ->
      `Assoc [
        "values", Values.to_json i.values;
        "name", (match i.name with Some n -> `String n | None -> `Null);
        "format", (match i.format_ with Some f -> Data_format.to_json f | None -> `Null);
      ]
    | `Name s -> `Assoc ["name", `String s]
end

module Mark = struct
  type t = [
    | `Bar
    | `Line
  ]

  let bar : t = `Bar
  let line : t = `Line

  let to_json : t -> json = function
    | `Bar -> `String "bar"
    | `Line -> `String "line"
end

module Encoding = struct
  type channel = [
    | `x | `y | `x2 | `y2
    | `xError | `yError | `xError2 | `yError2
    | `xOffset | `yOffset
    | `theta | `theta2 | `radius | `radius2
    | `longitude | `latitude | `longitude2 | `latitude2
    | `angle | `color | `fill | `stroke | `opacity | `fillopacity
    | `strokeOpacity | `shape | `size | `strokeDash | `strokeWidth
    | `text | `tooltip | `href | `description
    | `detail | `order | `facet | `row | `column
    | `other of string
  ]

  let str_of_chan (c:channel) =
    match c with
    | `other s -> s
    | `x -> "x" | `y -> "y" | `x2 -> "x2" | `y2 -> "y2"
    | `xError -> "xError" | `yError -> "yError"
    | `xError2 -> "xError2" | `yError2 -> "yError2"
    | `xOffset -> "xOffset" | `yOffset -> "yOffset"
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

  (** Type for a field.
      See https://vega.github.io/vega-lite/docs/encoding.html *)
  type field_type = [
    | `quantitative
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

  type scale = [
    | `other of json
  ]

  let json_of_scale : scale -> json = function
    | `other j -> j

  type bin = [
    | `bool of bool
    | `binned (** already binned *)
  ]

  let json_of_bin : bin -> json = function
    | `bool b -> `Bool b
    | `binned -> `String "binned"

  type aggregate = [
    | `mean | `sum | `median | `min | `max | `count | `other of json
  ]

  let json_of_aggregate : aggregate -> json = function
    | `mean -> `String "mean"
    | `sum -> `String "sum"
    | `median -> `String "median"
    | `min -> `String "min"
    | `max -> `String "max"
    | `count -> `String "count"
    | `other j -> j

  (* TODO: timeUnit *)
  (* TODO: axis *)
  (* TODO: legend *)
  (* TODO: format *)
  (* TODO: stack *)
  (* TODO: sort *)
  (* TODO: condition *)

  type field_def = {
    field: [`Field of string | `Repeat of string];
    type_: field_type option;
    bin: bin;
    aggregate: aggregate option;
    title: string option;
    scale: scale option;
  }

  type value = json
  type datum = json

  type definition = [
    | `Field of field_def
    | `Value of value
    | `Datum of datum
  ]

  type channel_def = {
    channel: channel;
    def: definition;
  }

  type t = channel_def list

  type 'a field_builder =
    channel ->
    ?bin:bin ->
    ?scale:scale ->
    ?title:string ->
    ?aggregate:aggregate ->
    'a

  let field_ channel ?(bin=`bool false) ?scale ?title
      ?aggregate ~field ~type_ () : channel_def =
    { channel; def=`Field {bin;title;aggregate;scale;field;type_}; }

  let field
      channel ?bin ?scale ?title ?aggregate ~name ~type_ () : channel_def =
    field_ channel ?bin ?scale ?title ?aggregate
      ~field:(`Field name) ~type_:(Some type_) ()

  let field_repeat_var
      channel ?bin ?scale ?title ?aggregate name : channel_def =
    field_ channel ?bin ?scale ?title ?aggregate
      ~field:(`Repeat name) ~type_:None ()

  let field_repeat
      channel ?bin ?scale ?title ?aggregate () : channel_def =
    field_ channel ?bin ?scale ?title ?aggregate
      ~field:(`Repeat "repeat") ~type_:None ()

  let datum channel d : channel_def =
    { channel; def=`Datum d; }
  let datum_i c i = datum c (`Int i)
  let datum_f c f = datum c (`Float f)
  let datum_s c s = datum c (`String s)

  let value channel d : channel_def =
    { channel; def=`Value d; }
  let value_i c i = value c (`Int i)
  let value_f c f = value c (`Float f)
  let value_s c s = value c (`String s)

  let json_of_chan_def (c:channel_def) : string * json =
    let def = match c.def with
      | `Value v -> `Assoc ["value", v]
      | `Datum v -> `Assoc ["datum", v]
      | `Field f ->
        let {field; type_; bin; scale; title; aggregate } = f in
        let l = List.flatten [
            ["field", (match field with
              | `Field s -> `String s
              | `Repeat s -> `Assoc ["repeat", `String s]);
             "bin", json_of_bin bin;
            ];
            (match scale with None -> [] | Some s -> ["scale", json_of_scale s]);
            (match type_ with
             | None -> [] | Some t -> ["type", json_of_field_type t]);
            (match title with None -> [] | Some s -> ["title", `String s]);
            (match aggregate with
             | None -> [] | Some s -> ["aggregate", json_of_aggregate s]);
          ] in
        `Assoc l
    in
    let c = str_of_chan c.channel in
    c, def

  let to_json (self:t) : json =
    let l = List.map json_of_chan_def self in
    `Assoc l
end

module Config = struct
  type t = json
  let json j : t = j
end

module Viz = struct
  type repeat_binding = {
    var: string;
    values: json list;
  }

  type repeat_spec =
    | R_simple of json list
    | R_full of {
        bind: repeat_binding list option;
        column: string list option;
        row: string list option;
        layer: string list option;
      }

  type t = {
    config: Config.t option;
    width:[`container | `int of int] option;
    height:[`container | `int of int] option;
    view: view;
  }
  and view =
    | Simple of {
        data: Data.t option;
        mark: Mark.t;
        encoding: Encoding.t option;
      }
    | Layer of t list
    | Hconcat of t list
    | Vconcat of t list
    | Concat of {
        concat: t list;
        columns: int;
      }
    | Repeat of {
        data: Data.t;
        repeat: repeat_spec;
        spec: t;
      }

  (** With options *)
  type 'a with_config =
    ?width:[`container | `int of int] ->
    ?height:[`container | `int of int] ->
    ?config:Config.t ->
    'a

  let bind ~var l : repeat_binding = {var; values=l}
  let bind_i ~var l = bind ~var (List.map (fun i->`Int i) l)
  let bind_f ~var l = bind ~var (List.map (fun f->`Float f) l)
  let bind_s ~var l = bind ~var (List.map (fun s->`String s) l)

  let mk ?width ?height ?config view : t =
    { width; height; config; view }

  let repeat ?width ?height ?config ?column ?row ?layer ?bind ~data spec : t =
    let is_none = function None -> true | Some _ -> false in
    if is_none column && is_none row && is_none layer && is_none bind then (
      invalid_arg "Viz.repeat: at least one repeating element has to be specified";
    );
    let repeat = R_full {bind; column; row; layer} in
    mk ?width ?height ?config @@ Repeat {spec; repeat; data; }

  let repeat_simple ?width ?height ?config ~repeat:l ~data spec : t =
    let l = List.map (fun s -> `String s) l in
    let repeat = R_simple l in
    mk ?width ?height ?config @@ Repeat {spec; repeat; data; }

  let layer ?width ?height ?config l : t =
    mk ?width ?height ?config @@ Layer l
  let hconcat ?width ?height ?config l =
    mk ?width ?height ?config @@ Hconcat l
  let vconcat ?width ?height ?config l =
      mk ?width ?height ?config @@ Vconcat l
  let concat ?width ?height ?config ~columns l : t =
    mk ?width ?height ?config @@ Concat {concat=l; columns}

  let make ?width ?height ?config ~data ~mark ?encoding () : t =
    mk ?width ?height ?config @@ Simple { data=Some data; mark; encoding; }

  let json_of_repeat (r:repeat_spec) : json =
    match r with
    | R_simple l ->
      `Assoc ["repeat", `List l]

    | R_full {column; row; layer; bind; } ->
      let js_binding (r:repeat_binding) : _ * json = r.var, `List r.values in
      let js_strl name = function
        | None -> []
        | Some l -> [name, `List (List.map (fun s->`String s) l)]
      in
      let l = List.flatten [
          js_strl "column" column;
          js_strl "row" row;
          js_strl "layer" layer;
          (match bind with
           | None -> []
           | Some l -> List.map js_binding l);
        ] in
      `Assoc l

  let rec to_json (self:t) : json =
    let conf = List.flatten [
        (match self.width with
         | Some (`container) -> ["width", `String "container"]
         | Some (`int i) -> ["width", `Int i]
         | None -> []);
        (match self.height with
         | Some (`container) -> ["height", `String "container"]
         | Some (`int i) -> ["height", `Int i]
         | None -> []);
        (match self.config with
         | None -> []
         | Some j -> ["config", j]);
      ]
    in
    let rest = match self.view with
      | Simple {mark; data; encoding} ->
        List.flatten [
          ["$schema", `String "https://vega.github.io/schema/vega-lite/v5.json";
           "mark", Mark.to_json mark;
          ];
          (match encoding with
           | None -> []
           | Some e -> ["encoding", Encoding.to_json e]);
          (match data with
           | None -> []
           | Some d -> ["data", Data.to_json d]);
        ]

      | Layer l ->
        ["layer", `List (List.map to_json l)]

      | Hconcat l ->
        ["hconcat", `List (List.map to_json l)]

      | Vconcat l ->
        ["vconcat", `List (List.map to_json l)]

      | Concat {concat=l; columns} ->
        ["concat", `List (List.map to_json l); "columns", `Int columns]

      | Repeat {data; repeat; spec} ->
        [
          "data", Data.to_json data;
          "repeat", json_of_repeat repeat;
          "spec", to_json spec;
        ]
    in
    `Assoc (List.rev_append conf rest)

  let to_json_str self = Yojson.Basic.pretty_to_string @@ to_json self

  let to_json_file self ~file =
    let j = to_json self in
    Yojson.Basic.to_file file j
end

(* check compat with yojson *)
let () =
  let j : json = `Null in
  let _j2 : Yojson.Basic.t = j in
  ()
