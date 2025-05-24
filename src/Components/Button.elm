module Components.Button exposing
    ( Button
    , new
    , withAttrs, withLoading, withOnClick, withChildren, withLeadingIcon, withSizeSmall, withText, withTrailingIcon, withVariantIconOnly, withVariantSecondary
    , toHtml
    )

{-|


# Button

@docs Button


# Constructor

@docs new


# Modifiers

@docs withAttrs, withLoading, withOnClick, withChildren, withLeadingIcon, withSizeSmall, withText, withTrailingIcon, withVariantIconOnly, withVariantSecondary


# View

@docs toHtml

-}

import Accessibility.Aria as Aria
import Components.Icon as Icon
import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Svg
import Svg.Attributes


type Button msg r
    = Settings
        { onClick : Maybe msg
        , attrs : List (Html.Attribute msg)
        , loading : Bool
        , variant : Variant
        , size : Size
        , leadingIcon : Maybe Icon.Path
        , trailingIcon : Maybe Icon.Path
        , children : List (Html msg)
        }


type Variant
    = Primary
    | Secondary
    | IconOnly { icon : Icon.Path, label : String }


type Size
    = Small
    | Medium


new : Button msg { r | lacksIcon : (), lacksChildren : () }
new =
    Settings
        { onClick = Nothing
        , attrs = []
        , loading = False
        , variant = Primary
        , size = Medium
        , leadingIcon = Nothing
        , trailingIcon = Nothing
        , children = []
        }


withOnClick : msg -> Button msg r -> Button msg r
withOnClick onClick (Settings settings) =
    Settings { settings | onClick = Just onClick }


withAttrs : List (Html.Attribute msg) -> Button msg r -> Button msg r
withAttrs attrs (Settings settings) =
    Settings { settings | attrs = attrs }


withLeadingIcon : Icon.Path -> Button msg { r | lacksIcon : () } -> Button msg { r | hasIcon : () }
withLeadingIcon icon (Settings settings) =
    Settings { settings | leadingIcon = Just icon }


withTrailingIcon : Icon.Path -> Button msg { r | lacksIcon : () } -> Button msg { r | hasIcon : () }
withTrailingIcon icon (Settings settings) =
    Settings { settings | trailingIcon = Just icon }


withSizeSmall : Button msg r -> Button msg r
withSizeSmall (Settings settings) =
    Settings { settings | size = Small }


withVariantSecondary : Button msg r -> Button msg r
withVariantSecondary (Settings settings) =
    Settings { settings | variant = Secondary }


withVariantIconOnly : Icon.Path -> String -> Button msg { r | lacksIcon : (), lacksChildren : () } -> Button msg { r | hasIcon : (), hasChildren : () }
withVariantIconOnly icon label (Settings settings) =
    Settings { settings | variant = IconOnly { icon = icon, label = label } }


withChildren : List (Html msg) -> Button msg { r | lacksChildren : () } -> Button msg { r | hasChildren : () }
withChildren children (Settings settings) =
    Settings { settings | children = children }


withText : String -> Button msg { r | lacksChildren : () } -> Button msg { r | hasChildren : () }
withText text (Settings settings) =
    Settings { settings | children = [ Html.text text ] }


withLoading : Bool -> Button msg r -> Button msg r
withLoading loading (Settings settings) =
    Settings
        { settings
            | loading = loading
            , attrs = Aria.disabled loading :: settings.attrs
        }


toHtml : Button msg { r | hasChildren : () } -> Html msg
toHtml (Settings settings) =
    let
        iconSize : Icon.Size
        iconSize =
            case settings.size of
                Small ->
                    Icon.Micro

                Medium ->
                    Icon.Regular

        children =
            case settings.variant of
                Primary ->
                    settings.children

                Secondary ->
                    settings.children

                IconOnly { icon } ->
                    [ Icon.view iconSize [] icon ]

        leadingIcon =
            settings.leadingIcon
                |> Maybe.map (Icon.view iconSize [])
                |> Maybe.withDefault (Html.text "")
                |> Html.map never

        trailingIcon =
            settings.trailingIcon
                |> Maybe.map (Icon.view iconSize [])
                |> Maybe.withDefault (Html.text "")
                |> Html.map never

        classAttr =
            case ( settings.variant, settings.size ) of
                ( Primary, Small ) ->
                    primarySmallClass

                ( Secondary, Small ) ->
                    secondarySmallClass

                ( Primary, Medium ) ->
                    primaryClass

                ( Secondary, Medium ) ->
                    secondaryClass

                ( IconOnly _, _ ) ->
                    iconClass
    in
    Html.button
        ((case settings.onClick of
            Just onClick ->
                Events.onClick onClick

            Nothing ->
                Attributes.class ""
         )
            :: Attributes.class "grid place-items-center font-semibold active:transition *:[grid-area:1/-1] aria-disabled:cursor-not-allowed aria-disabled:opacity-75"
            :: classAttr
            :: settings.attrs
        )
        [ Html.span
            [ Attributes.classList [ ( "invisible", settings.loading ) ]
            , Attributes.class "flex items-center gap-1"
            ]
            (leadingIcon
                :: children
                ++ [ trailingIcon ]
            )
        , if settings.loading then
            spinningThreeQuarterCircle
                [ case settings.size of
                    Small ->
                        Svg.Attributes.class "size-4"

                    Medium ->
                        Svg.Attributes.class "size-6"
                ]

          else
            Html.text ""
        ]



-- DEFAULTS


iconClass : Html.Attribute msg
iconClass =
    Attributes.class "p-3 rounded-full bg-gray-800/0 hover:bg-gray-800/5 active:bg-gray-800/10"


primaryClass : Html.Attribute msg
primaryClass =
    Attributes.class "py-2 px-4 text-white bg-gray-800 rounded-lg hover:bg-gray-900 active:bg-gray-950"


secondaryClass : Html.Attribute msg
secondaryClass =
    Attributes.class "py-2 px-4 text-gray-800 rounded-lg bg-gray-800/0 hover:bg-gray-800/5 active:bg-gray-800/10"


primarySmallClass : Html.Attribute msg
primarySmallClass =
    Attributes.class "py-1 px-2  text-sm text-white bg-gray-800 rounded-lg hover:bg-gray-900 active:bg-gray-950"


secondarySmallClass : Html.Attribute msg
secondarySmallClass =
    Attributes.class "py-1 px-2 text-sm text-gray-800 rounded-lg bg-gray-800/0 hover:bg-gray-800/5 active:bg-gray-800/10"


spinningThreeQuarterCircle : List (Svg.Attribute msg) -> Svg.Svg msg
spinningThreeQuarterCircle attrs =
    Svg.svg
        ([ Svg.Attributes.width "24"
         , Svg.Attributes.height "24"
         , Svg.Attributes.viewBox "0 0 24 24"
         , Svg.Attributes.fill "none"
         ]
            ++ attrs
        )
        [ Svg.path
            [ Svg.Attributes.strokeLinecap "round"
            , Svg.Attributes.strokeWidth "2"
            , Svg.Attributes.stroke "currentColor"
            , Svg.Attributes.d "M 10 10 m 8, 0 a 8,8 0 1,0 -16,0 a 8,8 0 0,0 8,8"
            , Svg.Attributes.class "animate-spin origin-center"
            ]
            []
        ]
