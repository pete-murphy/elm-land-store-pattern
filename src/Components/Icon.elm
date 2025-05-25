module Components.Icon exposing (..)

import Components.Icon.Path exposing (Path)
import Svg
import Svg.Attributes as Attributes


type Size
    = Regular
    | Micro


view : Size -> List (Svg.Attribute msg) -> Path -> Svg.Svg msg
view size attrs iconPath =
    let
        sizeStr =
            case size of
                Regular ->
                    "24"

                Micro ->
                    "16"

        path =
            case size of
                Regular ->
                    iconPath.size24

                Micro ->
                    iconPath.size16
    in
    Svg.svg
        ([ Attributes.width sizeStr
         , Attributes.height sizeStr
         , Attributes.viewBox ("0 0 " ++ sizeStr ++ " " ++ sizeStr)
         , Attributes.fill "none"
         ]
            ++ attrs
        )
        (path
            |> List.map
                (\d ->
                    Svg.path
                        [ Attributes.fillRule "evenodd"
                        , Attributes.clipRule "evenodd"
                        , Attributes.fill "currentColor"
                        , Attributes.d d
                        ]
                        []
                )
        )
