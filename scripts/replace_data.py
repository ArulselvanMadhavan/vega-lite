import argparse
import json
import os

spec = r"""{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "title": {
    "text": "Vit dashboard",
    "color": "green",
    "fontSize": 24,
    "anchor": "middle",
    "dy": -50
  },
  "hconcat": [
    {
      "data": {"name": "empty"},
      "repeat": {"row": ["accuracy", "loss", "elapsed_time"]},
      "spec": {
        "mark": {"type": "bar", "tooltip": {"content": "data"}},
        "encoding": {
          "x": {"field": "model", "bin": false, "type": "nominal"},
          "y": {
            "field": {"repeat": "row"},
            "bin": false,
            "type": "quantitative"
          },
          "xOffset": {"field": "hardware", "bin": false, "type": "nominal"},
          "color": {"field": "hardware", "bin": false, "type": "nominal"}
        },
        "data": {
          "values": "model,hardware,loss,accuracy,elapsed_time,fp32Percent\r\nvit_b_16,default-fp32,0.8932146759033203,79.2,4,100.0\r\nvit_b_16,envise-fp16,0.9713312368392945,77.0,480,97.22222222222221\r\nvit_b_16,envise-fp16-dft,0.9409958763122559,78.8,4,99.4949494949495\r\n",
          "name": "data/vit/eval.csv",
          "format": {"type": "csv", "parse": null}
        }
      }
    },
    {
      "vconcat": [
        {
          "layer": [
            {
              "mark": "rule",
              "encoding": {"y": {"datum": 99}, "color": {"value": "red"}},
              "data": {"name": "data/vit/eval.csv"}
            },
            {
              "mark": {
                "type": "text",
                "text": "99% threshold",
                "align": "right",
                "baseline": "middle",
                "x": "width",
                "dx": 75
              },
              "encoding": {"y": {"datum": 99}},
              "data": {"name": "data/vit/eval.csv"}
            },
            {
              "mark": {"type": "bar", "tooltip": {"content": "data"}},
              "encoding": {
                "x": {"field": "model", "bin": false, "type": "nominal"},
                "xOffset": {
                  "field": "hardware",
                  "bin": false,
                  "type": "nominal"
                },
                "color": {
                  "field": "hardware",
                  "bin": false,
                  "type": "nominal",
                  "legend": {"title": null}
                },
                "y": {
                  "field": "fp32Percent",
                  "bin": false,
                  "scale": {"domainMin": 90, "clamp": true},
                  "type": "quantitative",
                  "title": "% of FP32"
                }
              },
              "data": {"name": "data/vit/eval.csv"}
            }
          ]
        },
        {
          "data": {"name": "empty"},
          "repeat": {"row": ["mean", "std"]},
          "spec": {
            "title": "Layerwise Noise Distribution",
            "width": 400,
            "mark": "line",
            "encoding": {
              "x": {"field": "layer", "bin": false, "type": "nominal"},
              "y": {
                "field": {"repeat": "row"},
                "bin": false,
                "type": "quantitative"
              },
              "color": {"field": "model", "bin": false, "type": "nominal"}
            },
            "data": {
              "values": "model,layer,mean,std\r\nvit_b_16,conv_proj,2.5526151148369536e-05,0.031194662675261497\r\nvit_b_16,encoder.layers.encoder_layer_0.mlp.0,7.798736078257207e-06,0.0561346672475338\r\nvit_b_16,encoder.layers.encoder_layer_0.mlp.3,-3.874496906064451e-05,0.03551590442657471\r\nvit_b_16,encoder.layers.encoder_layer_1.mlp.0,0.00025379229919053614,0.08448588103055954\r\nvit_b_16,encoder.layers.encoder_layer_1.mlp.3,5.90395720792003e-05,0.024319881573319435\r\nvit_b_16,encoder.layers.encoder_layer_2.mlp.0,0.00018798669043462723,0.06026965007185936\r\nvit_b_16,encoder.layers.encoder_layer_2.mlp.3,-7.856525371607859e-06,0.02097204700112343\r\nvit_b_16,encoder.layers.encoder_layer_3.mlp.0,8.689485548529774e-05,0.05983556807041168\r\nvit_b_16,encoder.layers.encoder_layer_3.mlp.3,1.3422378287941683e-05,0.02315600775182247\r\nvit_b_16,encoder.layers.encoder_layer_4.mlp.0,0.00012312826584093273,0.05831853300333023\r\nvit_b_16,encoder.layers.encoder_layer_4.mlp.3,-3.91937792301178e-05,0.024931425228714943\r\nvit_b_16,encoder.layers.encoder_layer_5.mlp.0,0.00010385634959675372,0.05975311994552612\r\nvit_b_16,encoder.layers.encoder_layer_5.mlp.3,6.140822370070964e-05,0.03518925979733467\r\nvit_b_16,encoder.layers.encoder_layer_6.mlp.0,2.80610729532782e-05,0.06235561519861221\r\nvit_b_16,encoder.layers.encoder_layer_6.mlp.3,-1.9942628568969667e-05,0.03208409622311592\r\nvit_b_16,encoder.layers.encoder_layer_7.mlp.0,4.0794999222271144e-05,0.06601595133543015\r\nvit_b_16,encoder.layers.encoder_layer_7.mlp.3,5.149304797669174e-06,0.039079923182725906\r\nvit_b_16,encoder.layers.encoder_layer_8.mlp.0,3.8856378523632884e-05,0.06279455125331879\r\nvit_b_16,encoder.layers.encoder_layer_8.mlp.3,1.4939831089577638e-05,0.03869616240262985\r\nvit_b_16,encoder.layers.encoder_layer_9.mlp.0,4.5163007598603144e-05,0.059010736644268036\r\nvit_b_16,encoder.layers.encoder_layer_9.mlp.3,-4.048444679938257e-05,0.038477446883916855\r\nvit_b_16,encoder.layers.encoder_layer_10.mlp.0,3.8124751881696284e-05,0.0540541410446167\r\nvit_b_16,encoder.layers.encoder_layer_10.mlp.3,-0.00010558125359239057,0.059763163328170776\r\nvit_b_16,encoder.layers.encoder_layer_11.mlp.0,8.87653004610911e-05,0.05261818319559097\r\nvit_b_16,encoder.layers.encoder_layer_11.mlp.3,6.475437839981169e-05,0.017593881115317345\r\nvit_b_16,heads.head,-5.879393938812427e-05,0.03906862437725067\r\n",
              "name": "data/vit/layer.csv",
              "format": {"type": "csv", "parse": null}
            }
          }
        }
      ]
    }
  ]
}"""


def read_csv(file_name):
    with open(file_name, "r+") as f:
        text = f.read()
    return text


def gen_html(spec_json):
    return """<html>""" + """    <head>
<script src="https://cdn.jsdelivr.net/npm/vega@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
    </head>""" + """<body
     <div id="vis"></div>
     <script>vegaEmbed("#vis",""" + json.dumps(spec_json,
                                               indent=2) + """);</script>
   </body></html>"""


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=("Generate Idiom dashboard"))
    parser.add_argument(
        "--model-name",
        type=str,
        required=True,
        help="Model Name",
    )
    parser.add_argument(
        "--eval-path",
        metavar="PATH",
        type=str,
        required=True,
        help="Path to eval_results.csv",
    )
    parser.add_argument(
        "--layer-path",
        metavar="PATH",
        type=str,
        required=True,
        help="Path to layer_results.csv",
    )
    parser.add_argument(
        "--output-dir",
        metavar="PATH",
        type=str,
        required=True,
        help="Path to output dir",
    )
    args = parser.parse_args()
    eval_data = read_csv(args.eval_path)
    layer_data = read_csv(args.layer_path)
    _spec = json.loads(spec)
    _spec["title"]["text"] = args.model_name + " dashboard"
    _spec["hconcat"][0]["spec"]["data"]["values"] = eval_data
    _spec["hconcat"][1]["vconcat"][1]["spec"]["data"]["values"] = layer_data
    html = gen_html(_spec)
    
    os.makedirs(os.path.dirname(args.output_dir), exist_ok=True)
    with open(args.output_dir + "idiom-dashboard.html", "w+") as f:
        f.write(html)
    with open(args.output_dir + "idiom-dashboard.vl.json", "w+") as f:
        json.dump(_spec, f)
