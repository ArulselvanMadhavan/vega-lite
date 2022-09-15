import json
import itertools

def gen_mark(name):
    return [
    {
      "name": "column_footer",
      "type": "group",
      "role": "column-footer",
      "encode": {
        "update": {
          "width": {"signal": "child_width"},
          "height": {"signal": "child_height"}
        }
      },
      "axes": [
        {
          "scale": f"{name}_xscale",
          "orient": "bottom",
          "grid": False,
          "title": f"{name} distribution",
          "labelFlush": True,
          "labelOverlap": True,
          "tickCount": {"signal": "ceil(child_width/40)"},
          "ticks": True,
          "zindex": 0
        }
      ]
    },
    {
      "type": "group",
      "from": {
        "facet": {
          "data": f"{name}_0",
          "name": "category",
          "groupby": "layer_name"
        }
      },
      "encode": {
        "update": {
          "y": {"field": "layer_name", "scale": f"{name}_yscale"},
          "width": {"signal": "child_width"},
          "height": {"scale": f"{name}_yscale", "band": 1}
        }
      },
      "signals": [{"name": "height", "update": f"bandwidth('{name}_yscale')"}],
      "scales": [
        {
          "name": "yinner",
          "type": "linear",
          "range": [{"signal": "height"}, 0],
          "domain": [0, 1]
        }
      ],
      "marks": [
        {
          "type": "area",
          "from": {"data": "category"},
          "encode": {
            "enter": {
              "fill": {"scale": "color", "field": {"parent": "layer_name"}},
              "fillOpacity": {"value": 0.7},
              "stroke": {"value": "white"},
              "strokeWidth": {"value": 1}
            },
            "update": {
              "x": {"scale": f"{name}_xscale", "field": "value"},
              "y": {"scale": "yinner", "field": "density"},
              "y2": {"scale": "yinner", "value": 0}
            }
          }
        },
        {
          "type": "rule",
          "clip": True,
          "encode": {
            "update": {
              "y": {"signal": "height", "offset": -0.5},
              "x": {"scale": f"{name}_xscale", "field": {"parent": "value"}},
              "x2": {"signal": "child_width"},
              "stroke": {"value": "#aaa"},
              "strokeWidth": {"value": 0.25},
              "strokeOpacity": {"value": 1}
            }
          }
        }
      ]
    }
  ]

def gen_signals(layer_count):
  return [
    {"name": "child_width", "value": 250},
    {"name": "child_height", "value": 380},
    {
      "name": "layers",
      "value": [f"layer_{i}" for i in range(0, layer_count)]
    }
  ]    
    
kde_spec = r"""
{
  "$schema": "https://vega.github.io/schema/vega/v5.json",
  "padding": 5,
  "autosize": "pad",
  "config": {
    "text": {"font": "Ideal Sans, Avenir Next, Helvetica"},
    "title": {
      "font": "Ideal Sans, Avenir Next, Helvetica",
      "fontWeight": 500,
      "fontSize": 17,
      "limit": -1
    },
    "axis": {
      "labelFont": "Ideal Sans, Avenir Next, Helvetica",
      "labelFontSize": 12
    }
  },
  "signals": [
    {"name": "child_width", "value": 250},
    {"name": "child_height", "value": 380},
    {
      "name": "layers",
      "value": [
        "layer_0",
        "layer_1",
        "layer_2",
        "layer_3",
        "layer_4",
        "layer_5",
        "layer_6",
        "layer_7",
        "layer_8",
        "layer_9",
        "layer_10",
        "layer_11",
        "layer_12",
        "layer_13",
        "layer_14",
        "layer_15",
        "layer_16",
        "layer_17",
        "layer_18"
      ]
    }
  ],
  "scales": [
    {
      "name": "xscale",
      "type": "linear",
      "domain": {"data": "source_0", "field": "value"},
      "range": [0, {"signal": "child_width"}],
      "nice": true,
      "zero": true
    },
    {
      "name": "yscale",
      "type": "band",
      "range": [0, {"signal": "child_height"}],
      "round": true,
      "padding": 0,
      "domain": {"signal": "layers"}
    },
    {
      "name": "color",
      "type": "ordinal",
      "domain": {"data": "source_0", "field": "layer_name"},
      "range": "category"
    }
  ],
  "data": [
    {"name": "source", "url": "data/layer.csv", "format": {"type": "csv"}},
    {
      "name": "source_0",
      "url": "data/layer.csv",
      "format": {"type": "csv"},
      "transform": [
        {
          "type": "kde",
          "field": "value",
          "groupby": ["layer_name"],
          "extent": [-1, 2],
          "as": ["value", "density"],
          "steps": 200
        }
      ]
    }
  ]
}
"""

def gen_data(name):
    return {
      "name": f"{name}_0",
      "url": f"data/{name}.csv",
      "format": {"type": "csv"},
      "transform": [
        {
          "type": "kde",
          "field": "value",
          "groupby": ["layer_name"],
          "extent": [-1, 2],
          "as": ["value", "density"],
          "steps": 200
        }
      ]
    }

def gen_scales(name):
    return [
    {
      "name": f"{name}_xscale",
      "type": "linear",
      "domain": {"data": f"{name}_0", "field": "value"},
      "range": [0, {"signal": "child_width"}],
      "nice": True,
      "zero": True
    },
    {
      "name": f"{name}_yscale",
      "type": "band",
      "range": [0, {"signal": "child_height"}],
      "round": True,
      "padding": 0,
      "domain": {"signal": "layers"}
    }
  ]

def gen_color(names):
    return     {
      "name": f"color",
      "type": "ordinal",
      "domain": {"fields":[{"data": f"{name}_0", "field": "layer_name"} for name in names]},
      "range": "category"
    }

def gen_axes(name):
    return [
    {
      "scale": f"{name}_xscale",
      "orient": "bottom",
      "domain": False,
      "labels": False,
      "aria": False,
      "maxExtent": 0,
      "minExtent": 0,
      "ticks": False,
      "zindex": 0
    },
    {
      "orient": "left",
      "scale": f"{name}_yscale",
      "domain": False,
      "ticks": False,
      "encode": {
        "labels": {
          "update": {
            "width": {"signal": "child_width"},
            "dx": {"value": 2},
            "dy": {"value": 2},
            "y": {"scale": f"{name}_yscale", "field": "value", "band": 1},
            "baseline": {"value": "bottom"}
          }
        }
      }
    }
  ]

def group_mark(names):
    return [{
          "type":"group",
          "name": "concat_group",
          "layout": {"padding": 20, "columns": 3, "bounds": "full", "align": "all"},
          "marks":[{"type": "group","style":"cell","name":f"concat_{name}","marks":gen_mark(name), "axes":gen_axes(name)} for name in names]
          }]

if __name__ == "__main__":
    names = ["bias"]
    data_array = [gen_data(n) for n in names]
    scales_array = list(itertools.chain.from_iterable([gen_scales(n) for n in names]))
    scales_array = scales_array + [gen_color(names)]
    kde_spec = json.loads(kde_spec)
    kde_spec["data"] = data_array
    kde_spec["scales"] = scales_array
    kde_spec["marks"] = group_mark(names)
    kde_spec["signals"] = gen_signals(12) #Fixme
    with open("kde.json", "w+") as f:
        json.dump(kde_spec, f, indent=2)
    #print(kde_spec)
