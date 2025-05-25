module Components.Modal exposing
    ( Modal
    , new
    , toHtml
    , withModifyAttrs
    )

{-| A component for displaying a modal dialog (a native HTML `dialog` element,
opened via `dialog.showModal()`).
-}

import Components.Button as Button
import Components.Icon as Icon
import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Json.Decode


type Modal msg
    = Settings
        { onClose : msg
        , open : Bool
        , header : Maybe (Html msg)
        , attrs : List (Html.Attribute msg)
        , children : List (Html msg)
        }



-- CONSTRUCTOR


new :
    { onClose : msg
    , open : Bool
    }
    -> List (Html msg)
    -> Modal msg
new { onClose, open } children =
    Settings
        { onClose = onClose
        , open = open
        , header = Just defaultHeader
        , attrs = defaultAttrs
        , children = children
        }



-- MODIFIERS


withModifyAttrs : (List (Html.Attribute msg) -> List (Html.Attribute msg)) -> Modal msg -> Modal msg
withModifyAttrs modifier (Settings settings) =
    Settings { settings | attrs = modifier settings.attrs }



-- DESTRUCTOR


toHtml : Modal msg -> Html msg
toHtml (Settings settings) =
    let
        attrs =
            Events.on "close" (Json.Decode.succeed settings.onClose)
                :: settings.attrs
    in
    Html.node "modal-dialog-controller"
        [ Attributes.attribute "open"
            (if settings.open then
                "true"

             else
                "false"
            )
        ]
        [ Html.node "dialog"
            attrs
            (Maybe.withDefault (Html.text "") settings.header
                :: settings.children
            )
        ]



-- DEFAULTS


defaultAttrs : List (Html.Attribute msg)
defaultAttrs =
    [ Attributes.class "p-6 my-auto mx-auto text-gray-800 rounded-lg shadow-lg opacity-0 transform origin-center scale-95 translate-y-4 motion-safe:transition-all tablet:p-4 open:translate-y-0 open:scale-100 motion-safe:backdrop:transition-all open:backdrop:bg-gray-950/50 open:backdrop:starting:bg-gray-950/0 backdrop:bg-gray-950/0 transition-discrete open:starting:opacity-0 open:starting:translate-y-4 open:starting:scale-95 open:opacity-100" ]


defaultHeader : Html msg
defaultHeader =
    Html.form [ Attributes.class "grid justify-end", Attributes.method "dialog" ]
        [ Button.new
            |> Button.withVariantIconOnly Icon.x "Close"
            |> Button.withAttrs [ Attributes.autofocus True ]
            |> Button.toHtml
        ]
