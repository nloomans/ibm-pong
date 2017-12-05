port module Ports exposing (..)

-- These are subscription definitions that come from JavaScript. See ./index.js


port onKeyDown : (String -> msg) -> Sub msg


port tick : (Float -> msg) -> Sub msg
