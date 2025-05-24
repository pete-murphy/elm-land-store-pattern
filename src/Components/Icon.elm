module Components.Icon exposing (..)

import Svg
import Svg.Attributes as Attributes


view : List (Svg.Attribute msg) -> List (Svg.Svg msg) -> Svg.Svg msg
view attrs =
    Svg.svg
        ([ Attributes.width "24"
         , Attributes.height "24"
         , Attributes.viewBox "0 0 24 24"
         , Attributes.fill "none"
         ]
            ++ attrs
        )


x : List (Svg.Svg msg)
x =
    [ Svg.path
        [ Attributes.fillRule "evenodd"
        , Attributes.d "M5.47 5.47a.75.75 0 0 1 1.06 0L12 10.94l5.47-5.47a.75.75 0 1 1 1.06 1.06L13.06 12l5.47 5.47a.75.75 0 1 1-1.06 1.06L12 13.06l-5.47 5.47a.75.75 0 0 1-1.06-1.06L10.94 12 5.47 6.53a.75.75 0 0 1 0-1.06Z"
        , Attributes.clipRule "evenodd"
        ]
        []
    ]


spinningThreeQuarterCircle : List (Svg.Svg msg)
spinningThreeQuarterCircle =
    [ Svg.path
        [ Attributes.stroke "currentColor"
        , Attributes.strokeLinecap "round"
        , Attributes.strokeWidth "2"
        , Attributes.d "M 10 10 m 8, 0 a 8,8 0 1,0 -16,0 a 8,8 0 0,0 8,8"
        , Attributes.class "animate-spin origin-center"
        ]
        []
    ]
