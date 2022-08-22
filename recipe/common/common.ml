let output_dir = "outputs/"
let json_ext = ".json"
let html_ext = ".html"

let head =
  {|
    <head>
<script src="https://cdn.jsdelivr.net/npm/vega@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
    </head> 
|}
;;

let body spec =
  {|<body
     <div id="vis"></div>
     <script>vegaEmbed("#vis",|}
  ^ spec
  ^ {|);</script>
   </body>|}
;;

let gen_html spec = "<html>" ^ head ^ body spec ^ "</html>"
