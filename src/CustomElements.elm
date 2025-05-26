module CustomElements exposing (..)

import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Json.Decode


modalDialogController : Bool -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
modalDialogController isOpen attrs children =
    Html.node "modal-dialog-controller"
        [ Attributes.attribute "open"
            (if isOpen then
                "true"

             else
                "false"
            )
        ]
        [ Html.node "dialog" attrs children ]


intersectionContainer :
    { disabled : Bool
    , onIntersect : msg
    }
    -> List (Html.Attribute msg)
    -> List (Html msg)
    -> Html.Html msg
intersectionContainer props attrs =
    Html.node "intersection-sentinel"
        ([ Attributes.disabled props.disabled
         , Attributes.class "block"
         , Events.on "intersect" (Json.Decode.succeed props.onIntersect)
         ]
            ++ attrs
        )


intersectionSentinel :
    { disabled : Bool, onIntersect : msg }
    -> Html msg
intersectionSentinel props =
    intersectionContainer props [] []
