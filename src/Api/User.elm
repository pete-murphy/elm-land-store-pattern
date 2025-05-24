module Api.User exposing (..)

import Accessibility as Html exposing (Html)
import Auth.Credentials as Credentials exposing (Credentials)
import Html.Attributes
import Http
import Http.Extra exposing (Request)
import Iso8601
import Json.Decode exposing (Decoder)
import Json.Decode.Pipeline
import Paginated exposing (Paginated)
import Time exposing (Posix)
import Url.Builder


type User a
    = User Internals a


type alias Internals =
    { id : String
    , firstName : String
    , lastName : String
    , username : String
    , avatarUrl : String
    , role : Role
    }


type alias Preview =
    { -- TODO: Add something like "total posts" count
    }


type alias Details =
    { bio : Maybe String
    , email : String
    , isActive : Bool
    , createdAt : Posix
    , updatedAt : Posix
    }


type Role
    = Admin
    | Moderator
    | RegularUser



-- JSON


internalDecoder : Decoder Internals
internalDecoder =
    Json.Decode.succeed Internals
        |> Json.Decode.Pipeline.required "id" Json.Decode.string
        |> Json.Decode.Pipeline.required "firstName" Json.Decode.string
        |> Json.Decode.Pipeline.required "lastName" Json.Decode.string
        |> Json.Decode.Pipeline.required "username" Json.Decode.string
        |> Json.Decode.Pipeline.required "avatarUrl" Json.Decode.string
        |> Json.Decode.Pipeline.required "role" roleDecoder


decoder : Decoder a -> Decoder (User a)
decoder decoderA =
    Json.Decode.succeed User
        |> Json.Decode.Pipeline.custom internalDecoder
        |> Json.Decode.Pipeline.custom decoderA


previewDecoder : Decoder (User Preview)
previewDecoder =
    Json.Decode.succeed Preview
        |> decoder


detailsDecoder : Decoder (User Details)
detailsDecoder =
    Json.Decode.succeed Details
        |> Json.Decode.Pipeline.required "bio" (Json.Decode.nullable Json.Decode.string)
        |> Json.Decode.Pipeline.required "email" Json.Decode.string
        |> Json.Decode.Pipeline.required "isActive" Json.Decode.bool
        |> Json.Decode.Pipeline.required "createdAt" Iso8601.decoder
        |> Json.Decode.Pipeline.required "updatedAt" Iso8601.decoder
        |> decoder


roleDecoder : Decoder Role
roleDecoder =
    Json.Decode.string
        |> Json.Decode.andThen
            (\roleString ->
                case roleString of
                    "admin" ->
                        Json.Decode.succeed Admin

                    "moderator" ->
                        Json.Decode.succeed Moderator

                    "user" ->
                        Json.Decode.succeed RegularUser

                    _ ->
                        Json.Decode.fail ("Unknown role: " ++ roleString)
            )



-- HTTP


list :
    Credentials
    -> { page : Int, limit : Int }
    -> Request (Paginated (User Preview))
list credentials { page, limit } =
    let
        queryParams =
            [ Url.Builder.int "page" page
            , Url.Builder.int "limit" limit
            ]

        -- ++ (case search of
        --         Just searchTerm ->
        --             [ Url.Builder.string "search" searchTerm ]
        --         Nothing ->
        --             []
        --    )
    in
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "users" ] queryParams
    , body = Http.emptyBody
    , decoder = Paginated.decoder previewDecoder
    }


get :
    Credentials
    -> String
    -> Request (User Details)
get credentials userId =
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "users", userId ] []
    , body = Http.emptyBody
    , decoder = detailsDecoder
    }



-- HTML


viewPreviewList : List (User Preview) -> Html msg
viewPreviewList users =
    Html.ul [ Html.Attributes.class "flex flex-col gap-3" ]
        (List.map viewPreview users)


viewPreview : User Preview -> Html msg
viewPreview (User internals _) =
    Html.div
        [ Html.Attributes.class "flex gap-3 items-center" ]
        [ Html.img ""
            [ Html.Attributes.alt (internals.firstName ++ " " ++ internals.lastName)
            , Html.Attributes.class "w-10 h-10 rounded-full"
            , Html.Attributes.src internals.avatarUrl
            ]
        , Html.div [ Html.Attributes.class "flex-1" ]
            [ Html.div [ Html.Attributes.class "font-medium" ]
                [ Html.text (internals.firstName ++ " " ++ internals.lastName) ]
            , Html.div [ Html.Attributes.class "text-sm text-gray-500" ]
                [ Html.text ("@" ++ internals.username) ]
            ]
        ]


roleToString : Role -> String
roleToString role =
    case role of
        Admin ->
            "Admin"

        Moderator ->
            "Moderator"

        RegularUser ->
            "User"
