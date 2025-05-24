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


intersectionSentinel :
    { disabled : Bool
    , onIntersect : msg
    }
    -> Html.Html msg
intersectionSentinel props =
    Html.node "intersection-sentinel"
        [ Attributes.disabled props.disabled
        , Attributes.class "block"
        , Events.on "intersect" (Json.Decode.succeed props.onIntersect)
        ]
        []
