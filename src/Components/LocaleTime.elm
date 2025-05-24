module Components.LocaleTime exposing
    ( LocaleTime
    , new
    , withLocaleAttrs, withRelativeAttrs
    , withTimeStyle, withDateStyle
    , toHtml
    )

{-|


# LocaleTime

@docs LocaleTime

@docs new

@docs withLocaleAttrs, withRelativeAttrs
@docs withTimeStyle, withDateStyle

@docs toHtml

-}

import Html exposing (Html)
import Html.Attributes as Attributes
import Iso8601
import Maybe.Extra
import Time


type LocaleTime msg
    = Settings
        { posix : Time.Posix
        , dateStyle : Maybe String
        , timeStyle : Maybe String
        , localeAttrs : Maybe (List (Html.Attribute msg))
        , relativeAttrs : Maybe (List (Html.Attribute msg))
        }


new : Time.Posix -> LocaleTime msg
new posix =
    Settings
        { posix = posix
        , dateStyle = defaultDateStyle
        , timeStyle = defaultTimeStyle
        , localeAttrs = Nothing
        , relativeAttrs = Nothing
        }


withLocaleAttrs : List (Html.Attribute msg) -> LocaleTime msg -> LocaleTime msg
withLocaleAttrs attrs (Settings settings) =
    Settings { settings | localeAttrs = Just attrs }


withRelativeAttrs : List (Html.Attribute msg) -> LocaleTime msg -> LocaleTime msg
withRelativeAttrs attrs (Settings settings) =
    Settings { settings | relativeAttrs = Just attrs }


withTimeStyle : Maybe String -> LocaleTime msg -> LocaleTime msg
withTimeStyle timeStyle (Settings settings) =
    Settings { settings | timeStyle = timeStyle }


withDateStyle : Maybe String -> LocaleTime msg -> LocaleTime msg
withDateStyle dateStyle (Settings settings) =
    Settings { settings | dateStyle = dateStyle }


toHtml : LocaleTime msg -> List (Html msg)
toHtml (Settings settings) =
    let
        localeAttrs =
            settings.localeAttrs |> Maybe.withDefault defaultLocaleAttrs

        relativeAttrs =
            settings.relativeAttrs |> Maybe.withDefault defaultRelativeAttrs

        timeStyle =
            settings.timeStyle

        dateStyle =
            settings.dateStyle
    in
    [ localeDateTime
        { posix = settings.posix
        , dateStyle = dateStyle
        , timeStyle = timeStyle
        }
        localeAttrs
    , relativeTime settings.posix relativeAttrs
    ]



-- DEFAULTS


defaultTimeStyle : Maybe String
defaultTimeStyle =
    Just "long"


defaultDateStyle : Maybe String
defaultDateStyle =
    Just "long"


defaultLocaleAttrs : List (Html.Attribute msg)
defaultLocaleAttrs =
    []


defaultRelativeAttrs : List (Html.Attribute msg)
defaultRelativeAttrs =
    [ Attributes.class "text-sm text-gray-500" ]



-- CUSTOM ELEMENTS


localeDateTime :
    { posix : Time.Posix
    , dateStyle : Maybe String
    , timeStyle : Maybe String
    }
    -> List (Html.Attribute msg)
    -> Html msg
localeDateTime props attributes =
    Html.node "locale-datetime"
        ([ Attributes.attribute "millis" (String.fromInt (Time.posixToMillis props.posix))
         , case props.dateStyle of
            Just dateStyle ->
                Attributes.attribute "date-style" dateStyle

            Nothing ->
                Attributes.class ""
         , case props.timeStyle of
            Just timeStyle ->
                Attributes.attribute "time-style" timeStyle

            Nothing ->
                Attributes.class ""
         ]
            ++ attributes
        )
        []


relativeTime :
    Time.Posix
    -> List (Html.Attribute msg)
    -> Html msg
relativeTime posix attributes =
    Html.node "relative-time"
        (Attributes.attribute "datetime" (Iso8601.fromTime posix)
            :: Attributes.attribute "threshold" "P10Y"
            :: attributes
        )
        []
