module Components.IntersectionObservee exposing (..)

import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Json.Decode


type IntersectionObservee msg r
    = Settings
        { onIntersect : msg
        , attrs : Maybe (List (Html.Attribute msg))
        , disabled : Bool
        , children : List (Html msg)
        }


new : msg -> IntersectionObservee msg { r | lacksChildren : () }
new onIntersect =
    Settings
        { onIntersect = onIntersect
        , attrs = Nothing
        , disabled = False
        , children = []
        }


withAttrs : List (Html.Attribute msg) -> IntersectionObservee msg r -> IntersectionObservee msg r
withAttrs attrs (Settings settings) =
    Settings { settings | attrs = Just attrs }


withDisabled : Bool -> IntersectionObservee msg r -> IntersectionObservee msg r
withDisabled disabled (Settings settings) =
    Settings { settings | disabled = disabled }


withChildren : List (Html msg) -> IntersectionObservee msg r -> IntersectionObservee msg r
withChildren children (Settings settings) =
    Settings { settings | children = children }


toHtml : IntersectionObservee msg r -> Html msg
toHtml (Settings settings) =
    Html.node "intersection-observee"
        (Maybe.withDefault [ Attributes.class "block" ] settings.attrs
            ++ [ Attributes.disabled settings.disabled
               , Events.on "intersect" (Json.Decode.succeed settings.onIntersect)
               ]
        )
        settings.children
