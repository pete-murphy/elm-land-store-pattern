module Components.Button exposing
    ( Button
    , iconClass
    , new
    , primaryClass
    , primarySmallClass
    , secondaryClass
    , secondarySmallClass
    , toHtml
    , withAttrs
    , withIconClass
    , withLoading
    , withOnClick
    , withPrimaryClass
    , withPrimarySmallClass
    , withSecondaryClass
    , withSecondarySmallClass
    )

import Accessibility.Aria as Aria
import Components.Icon as Icon
import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Svg.Attributes


type Button msg
    = Settings
        { onClick : Maybe msg
        , attrs : List (Html.Attribute msg)
        , loading : Bool
        }


new : Button msg
new =
    Settings
        { onClick = Nothing
        , attrs = []
        , loading = False
        }


withOnClick : msg -> Button msg -> Button msg
withOnClick onClick (Settings settings) =
    Settings { settings | onClick = Just onClick }


withAttrs : List (Html.Attribute msg) -> Button msg -> Button msg
withAttrs attrs (Settings settings) =
    Settings { settings | attrs = attrs }


withPrimaryClass : Button msg -> Button msg
withPrimaryClass (Settings settings) =
    Settings { settings | attrs = primaryClass :: settings.attrs }


withSecondaryClass : Button msg -> Button msg
withSecondaryClass (Settings settings) =
    Settings { settings | attrs = secondaryClass :: settings.attrs }


withPrimarySmallClass : Button msg -> Button msg
withPrimarySmallClass (Settings settings) =
    Settings { settings | attrs = primarySmallClass :: settings.attrs }


withSecondarySmallClass : Button msg -> Button msg
withSecondarySmallClass (Settings settings) =
    Settings { settings | attrs = secondarySmallClass :: settings.attrs }


withIconClass : Button msg -> Button msg
withIconClass (Settings settings) =
    Settings { settings | attrs = iconClass :: settings.attrs }


withLoading : Bool -> Button msg -> Button msg
withLoading loading (Settings settings) =
    Settings
        { settings
            | loading = loading
            , attrs = Aria.disabled loading :: settings.attrs
        }


toHtml : List (Html msg) -> Button msg -> Html msg
toHtml children (Settings settings) =
    Html.button
        ((case settings.onClick of
            Just onClick ->
                Events.onClick onClick

            Nothing ->
                Attributes.class ""
         )
            :: Attributes.class "grid place-items-center font-semibold active:transition *:[grid-area:1/-1] aria-disabled:cursor-not-allowed"
            :: settings.attrs
        )
        [ Html.span [ Attributes.classList [ ( "invisible", settings.loading ) ] ]
            children
        , if settings.loading then
            Icon.view [ Svg.Attributes.class "size-4" ]
                Icon.spinningThreeQuarterCircle

          else
            Html.text ""
        ]



-- DEFAULTS


iconClass : Html.Attribute msg
iconClass =
    Attributes.class "p-3 rounded-full bg-gray-800/0 hover:bg-gray-800/5 active:bg-gray-800/10"


primaryClass : Html.Attribute msg
primaryClass =
    Attributes.class "py-4 px-8 text-white bg-gray-800 rounded-lg hover:bg-gray-900 active:bg-gray-950"


secondaryClass : Html.Attribute msg
secondaryClass =
    Attributes.class "py-4 px-8 text-gray-800 rounded-lg bg-gray-800/0 hover:bg-gray-800/5 active:bg-gray-800/10"


primarySmallClass : Html.Attribute msg
primarySmallClass =
    Attributes.class "py-1 px-2  text-sm text-white bg-gray-800 rounded-lg hover:bg-gray-900 active:bg-gray-950"


secondarySmallClass : Html.Attribute msg
secondarySmallClass =
    Attributes.class "py-1 px-2 text-sm text-gray-800 rounded-lg bg-gray-800/0 hover:bg-gray-800/5 active:bg-gray-800/10"
