module Api.User exposing (..)

import Accessibility as Html exposing (Html)
import Api.UserId as UserId exposing (UserId)
import Auth.Credentials as Credentials exposing (Credentials)
import Html.Attributes
import Http
import Http.Extra exposing (Request)
import Iso8601
import Json.Decode exposing (Decoder)
import Json.Decode.Pipeline
import Paginated exposing (Paginated)
import Route.Path
import Time exposing (Posix)
import Url.Builder


type User a
    = User Internals a


type alias Internals =
    { id : UserId
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
        |> Json.Decode.Pipeline.required "id" UserId.decoder
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
    -> { limit : Int }
    -> Request (Paginated (User Preview))
list credentials { limit } =
    let
        queryParams =
            [ Url.Builder.int "limit" limit
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
    , path = [ "api", "users" ]
    , query = queryParams
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
    , path = [ "api", "users", userId ]
    , query = []
    , body = Http.emptyBody
    , decoder = detailsDecoder
    }


getById :
    Credentials
    -> UserId
    -> Request (User Details)
getById credentials userId =
    get credentials (UserId.toString userId)



-- GETTERS


id : User a -> UserId
id (User internals _) =
    internals.id


firstName : User a -> String
firstName (User internals _) =
    internals.firstName


lastName : User a -> String
lastName (User internals _) =
    internals.lastName


username : User a -> String
username (User internals _) =
    internals.username


fullName : User a -> String
fullName (User internals _) =
    internals.firstName ++ " " ++ internals.lastName


avatarUrl : User a -> String
avatarUrl (User internals _) =
    internals.avatarUrl


role : User a -> Role
role (User internals _) =
    internals.role


bio : User Details -> Maybe String
bio (User _ details) =
    details.bio


email : User Details -> String
email (User _ details) =
    details.email


isActive : User Details -> Bool
isActive (User _ details) =
    details.isActive


createdAt : User Details -> Posix
createdAt (User _ details) =
    details.createdAt


updatedAt : User Details -> Posix
updatedAt (User _ details) =
    details.updatedAt



-- HTML


viewPreviewList : List (User Preview) -> Html msg
viewPreviewList users =
    Html.ul [ Html.Attributes.class "flex flex-col gap-3" ]
        (List.map viewPreview users)


viewPreview : User Preview -> Html msg
viewPreview (User internals _) =
    Html.a
        [ Route.Path.href (Route.Path.Users_UserId_ { userId = UserId.toString internals.id })
        , Html.Attributes.class "flex gap-3 items-center p-3 rounded-lg transition-colors hover:bg-gray-50"
        ]
        [ Html.img ""
            [ Html.Attributes.class "w-10 h-10 rounded-full"
            , Html.Attributes.src internals.avatarUrl
            ]
        , Html.div [ Html.Attributes.class "flex-1" ]
            [ Html.div [ Html.Attributes.class "font-medium" ]
                [ Html.text (internals.firstName ++ " " ++ internals.lastName) ]
            , Html.div [ Html.Attributes.class "text-sm text-gray-600" ]
                [ Html.text ("@" ++ internals.username) ]
            ]
        ]


roleToString : Role -> String
roleToString userRole =
    case userRole of
        Admin ->
            "Admin"

        Moderator ->
            "Moderator"

        RegularUser ->
            "User"
