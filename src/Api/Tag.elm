module Api.Tag exposing (..)

import Accessibility as Html exposing (Html)
import Auth.Credentials as Credentials exposing (Credentials)
import Html.Attributes
import Http
import Http.Extra exposing (Request)
import Iso8601
import Json.Decode exposing (Decoder)
import Json.Decode.Pipeline
import Route.Path
import Time exposing (Posix)
import Url.Builder


type alias Tag =
    { id : String
    , name : String
    , slug : String
    , description : Maybe String
    , color : String
    , createdAt : Posix
    }



-- JSON


decoder : Decoder Tag
decoder =
    Json.Decode.succeed Tag
        |> Json.Decode.Pipeline.required "id" Json.Decode.string
        |> Json.Decode.Pipeline.required "name" Json.Decode.string
        |> Json.Decode.Pipeline.required "slug" Json.Decode.string
        |> Json.Decode.Pipeline.optional "description" (Json.Decode.nullable Json.Decode.string) Nothing
        |> Json.Decode.Pipeline.required "color" Json.Decode.string
        |> Json.Decode.Pipeline.required "createdAt" Iso8601.decoder



-- HTTP


get :
    Credentials
    -> Request (List Tag)
get credentials =
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "tags" ] []
    , body = Http.emptyBody
    , decoder = Json.Decode.list decoder
    }



-- HTML


view : Tag -> Html msg
view tag =
    Html.div
        [ Html.Attributes.class "flex gap-2 items-center py-0.5 px-2 text-xs font-medium rounded text-[color-mix(in_oklch,var(--color)_25%,oklch(0%_0_0/80%))] bg-[color-mix(in_oklch,var(--color)_10%,oklch(100%_0_0))]"
        , Html.Attributes.attribute "style" ("--color:" ++ tag.color)
        ]
        [ Html.text tag.name
        ]


viewClickable : Tag -> Html msg
viewClickable tag =
    Html.a
        [ Route.Path.href (Route.Path.Tags_Slug_ { slug = tag.slug })
        , Html.Attributes.class "flex gap-2 items-center py-0.5 px-2 text-xs font-medium rounded text-[color-mix(in_oklch,var(--color)_25%,oklch(0%_0_0/80%))] bg-[color-mix(in_oklch,var(--color)_10%,oklch(100%_0_0))] hover:bg-[color-mix(in_oklch,var(--color)_15%,oklch(100%_0_0))] transition-colors"
        , Html.Attributes.attribute "style" ("--color:" ++ tag.color)
        ]
        [ Html.text tag.name
        ]


viewList : List Tag -> Html msg
viewList tags =
    Html.ul [ Html.Attributes.class "flex flex-wrap gap-2" ]
        (List.map view tags)


viewClickableList : List Tag -> Html msg
viewClickableList tags =
    Html.ul [ Html.Attributes.class "flex flex-wrap gap-2" ]
        (List.map viewClickable tags)
