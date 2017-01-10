# Chainerboard

## Requirements

- Ruby
    - only with standard library
- gnuplot _5.0_
    - using terminal _pngcairo_

## Usage

```bash
chainerboard --log /path/to/chainer/result/log [ --port 20080 ]
```

and access `localhost:20080/`.

`Chainerboard` generates like this:

![](resources/readme.png)

## LogReport format

```json
[
  {
    "epoch": 0,
    "iteration": 100,
    "main/loss_l": 0.18206550180912018,
    "main/acc": 0.33833333333333326,
    "main/loss": 0.32356593012809753,
    "validation/main/loss_l": 0.16721396148204803,
    "validation/main/acc": 0.3473333333333332,
    "validation/main/loss": 0.265784353017807
  },
  {
```

## LogPlot

A HTML page `localhost:20080/` shows 2 plots,
`/log/epoch` and
`/log/iteration`.

![](resources/readme.2.png)

### plot Images

You can wget `/log/epoch` and `/log/iteration` directly.
These images can accept some query parameters.

- xrange
    - example: `xrange=0.8:1.0`
- yrange
    - example: `yrange=0:`
- xtics
    - example: `xtics=0.1`
- ytics
    - example: `ytics=0.1`

