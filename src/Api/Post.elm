module Api.Post exposing
    ( CreatePostRequest
    , Details
    , Post
    , Preview
    , Status(..)
    , author
    , content
    , create
    , createdAt
    , delete
    , detailsDecoder
    , excerpt
    , get
    , id
    , list
    , listByTag
    , listByUser
    , previewDecoder
    , slug
    , status
    , statusDecoder
    , statusToString
    , tags
    , title
    , update
    , updatedAt
    , viewCount
    , viewPreview
    , viewPreviewList
    )

import Accessibility as Html exposing (Html)
import Api.Slug as Slug exposing (Slug)
import Api.Tag as Tag exposing (Tag)
import Api.TagId as TagId exposing (TagId)
import Api.User as User exposing (User)
import Api.UserId as UserId exposing (UserId)
import Auth.Credentials as Credentials exposing (Credentials)
import Components.LocaleTime as LocaleTime
import Html.Attributes
import Http
import Http.Extra exposing (Request)
import Iso8601
import Json.Decode exposing (Decoder)
import Json.Decode.Pipeline
import Json.Encode as Encode
import Paginated exposing (Paginated)
import Route.Path
import Time exposing (Posix)
import Url.Builder


type Post a
    = Post Internals a


type alias Internals =
    { id : String
    , title : String
    , excerpt : String
    , slug : String
    , status : Status
    , author : User User.Preview
    , tags : List Tag
    , viewCount : Int
    , createdAt : Posix
    , updatedAt : Posix
    }


type alias Preview =
    {}


type alias Details =
    { content : String
    }


type Status
    = Draft
    | Published



-- JSON


internalDecoder : Decoder Internals
internalDecoder =
    Json.Decode.succeed Internals
        |> Json.Decode.Pipeline.required "id" Json.Decode.string
        |> Json.Decode.Pipeline.required "title" Json.Decode.string
        |> Json.Decode.Pipeline.required "excerpt" Json.Decode.string
        |> Json.Decode.Pipeline.required "slug" Json.Decode.string
        |> Json.Decode.Pipeline.required "status" statusDecoder
        |> Json.Decode.Pipeline.required "author" User.previewDecoder
        |> Json.Decode.Pipeline.required "tags" (Json.Decode.list Tag.decoder)
        |> Json.Decode.Pipeline.required "viewCount" Json.Decode.int
        |> Json.Decode.Pipeline.required "createdAt" Iso8601.decoder
        |> Json.Decode.Pipeline.required "updatedAt" Iso8601.decoder


decoder : Decoder a -> Decoder (Post a)
decoder decoderA =
    Json.Decode.succeed Post
        |> Json.Decode.Pipeline.custom internalDecoder
        |> Json.Decode.Pipeline.custom decoderA


previewDecoder : Decoder (Post Preview)
previewDecoder =
    Json.Decode.succeed {}
        |> decoder


detailsDecoder : Decoder (Post Details)
detailsDecoder =
    Json.Decode.succeed Details
        |> Json.Decode.Pipeline.required "content" Json.Decode.string
        |> decoder


statusDecoder : Decoder Status
statusDecoder =
    Json.Decode.string
        |> Json.Decode.andThen
            (\statusString ->
                case statusString of
                    "draft" ->
                        Json.Decode.succeed Draft

                    "published" ->
                        Json.Decode.succeed Published

                    _ ->
                        Json.Decode.fail ("Unknown status: " ++ statusString)
            )



-- HTTP


list :
    Credentials
    -> { page : Int, limit : Int, status : Maybe Status, search : Maybe String }
    -> Request (Paginated (Post Preview))
list credentials params =
    let
        queryParams =
            [ Url.Builder.int "page" params.page
            , Url.Builder.int "limit" params.limit
            ]
                ++ (case params.status of
                        Just statusValue ->
                            [ Url.Builder.string "status" (statusToString statusValue) ]

                        Nothing ->
                            []
                   )
                ++ (case params.search of
                        Just searchTerm ->
                            [ Url.Builder.string "search" searchTerm ]

                        Nothing ->
                            []
                   )
    in
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "posts" ] queryParams
    , body = Http.emptyBody
    , decoder = Paginated.decoder previewDecoder
    }


listByTag :
    Credentials
    -> TagId
    -> { page : Int, limit : Int }
    -> Request (Paginated (Post Preview))
listByTag credentials tagId params =
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url =
        Url.Builder.absolute
            [ "api", "tags", TagId.toString tagId, "posts" ]
            [ Url.Builder.int "page" params.page
            , Url.Builder.int "limit" params.limit
            ]
    , body = Http.emptyBody
    , decoder = Paginated.decoder previewDecoder
    }


listByUser :
    Credentials
    -> UserId
    -> { page : Int, limit : Int }
    -> Request (Paginated (Post Preview))
listByUser credentials userId params =
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url =
        Url.Builder.absolute
            [ "api", "users", UserId.toString userId, "posts" ]
            [ Url.Builder.int "page" params.page
            , Url.Builder.int "limit" params.limit
            ]
    , body = Http.emptyBody
    , decoder = Paginated.decoder previewDecoder
    }


get :
    Credentials
    -> Slug
    -> Request (Post Details)
get credentials slug_ =
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "posts", "slug", Slug.toString slug_ ] []
    , body = Http.emptyBody
    , decoder = detailsDecoder
    }


type alias CreatePostRequest =
    { title : String
    , content : String
    , excerpt : Maybe String
    , status : Status
    , tagIds : List String
    }


create :
    Credentials
    -> CreatePostRequest
    -> Request (Post Details)
create credentials request =
    { method = "POST"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "posts" ] []
    , body =
        Http.jsonBody
            (Encode.object
                [ ( "title", Encode.string request.title )
                , ( "content", Encode.string request.content )
                , ( "excerpt", Maybe.map Encode.string request.excerpt |> Maybe.withDefault Encode.null )
                , ( "status", Encode.string (statusToString request.status) )
                , ( "tagIds", Encode.list Encode.string request.tagIds )
                ]
            )
    , decoder = detailsDecoder
    }


type alias UpdatePostRequest =
    { title : Maybe String
    , content : Maybe String
    , excerpt : Maybe String
    , status : Maybe Status
    , tagIds : Maybe (List String)
    }


update :
    Credentials
    -> String
    -> UpdatePostRequest
    -> Request (Post Details)
update credentials postId request =
    let
        encodeOptional key encoder maybeValue =
            case maybeValue of
                Just value ->
                    [ ( key, encoder value ) ]

                Nothing ->
                    []

        requestBody =
            Encode.object
                (encodeOptional "title" Encode.string request.title
                    ++ encodeOptional "content" Encode.string request.content
                    ++ encodeOptional "excerpt" Encode.string request.excerpt
                    ++ encodeOptional "status" (statusToString >> Encode.string) request.status
                    ++ encodeOptional "tagIds" (Encode.list Encode.string) request.tagIds
                )
    in
    { method = "PATCH"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "posts", postId ] []
    , body = Http.jsonBody requestBody
    , decoder = detailsDecoder
    }


delete :
    Credentials
    -> String
    -> Request ()
delete credentials postId =
    { method = "DELETE"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "posts", postId ] []
    , body = Http.emptyBody
    , decoder = Json.Decode.succeed ()
    }



-- HTML


viewPreviewList : List (Post Preview) -> Html msg
viewPreviewList posts =
    Html.ul [ Html.Attributes.class "flex flex-col gap-8" ]
        (List.map viewPreview posts)


viewPreview : Post Preview -> Html msg
viewPreview (Post internals _) =
    Html.li []
        [ Html.article
            [ Html.Attributes.class "" ]
            [ Html.header [ Html.Attributes.class "flex gap-4 justify-between items-start mb-3" ]
                [ Html.div [ Html.Attributes.class "flex-1" ]
                    [ Html.h3 [ Html.Attributes.class "mb-1 text-lg font-semibold" ]
                        [ Html.a
                            [ Route.Path.href (Route.Path.Posts_Slug_ { slug = internals.slug })
                            , Html.Attributes.class "underline underline-offset-2 decoration-2"
                            ]
                            [ Html.text internals.title ]
                        ]
                    , Html.div [ Html.Attributes.class "flex gap-2 items-center text-sm text-gray-600" ]
                        [ Html.text ("by " ++ username internals.author)
                        , Html.text " • "
                        , Html.text (statusToString internals.status)
                        , Html.text " • "
                        , Html.text (String.fromInt internals.viewCount ++ " views")
                        ]
                    ]
                ]
            , Html.p [ Html.Attributes.class "mb-3 text-gray-600" ]
                [ Html.text internals.excerpt ]
            , Html.footer [ Html.Attributes.class "flex justify-between items-center" ]
                [ if List.isEmpty internals.tags then
                    Html.div [] []

                  else
                    Tag.viewClickableList internals.tags
                , Html.div [ Html.Attributes.class "flex gap-1 text-sm text-gray-600 text-end text-nowrap line-clamp-1" ]
                    (LocaleTime.new internals.createdAt
                        |> LocaleTime.withTimeStyle Nothing
                        |> LocaleTime.withLocaleAttrs []
                        |> LocaleTime.withRelativeAttrs []
                        |> LocaleTime.toHtml
                        |> List.intersperse (Html.text " • ")
                    )
                ]
            ]
        ]


statusToString : Status -> String
statusToString statusValue =
    case statusValue of
        Draft ->
            "draft"

        Published ->
            "published"



-- GETTERS (following the established pattern)


id : Post a -> String
id (Post internals _) =
    internals.id


title : Post a -> String
title (Post internals _) =
    internals.title


excerpt : Post a -> String
excerpt (Post internals _) =
    internals.excerpt


slug : Post a -> String
slug (Post internals _) =
    internals.slug


status : Post a -> Status
status (Post internals _) =
    internals.status


author : Post a -> User User.Preview
author (Post internals _) =
    internals.author


tags : Post a -> List Tag
tags (Post internals _) =
    internals.tags


viewCount : Post a -> Int
viewCount (Post internals _) =
    internals.viewCount


createdAt : Post a -> Posix
createdAt (Post internals _) =
    internals.createdAt


updatedAt : Post a -> Posix
updatedAt (Post internals _) =
    internals.updatedAt


content : Post Details -> String
content (Post _ details) =
    details.content


username : User User.Preview -> String
username (User.User internals _) =
    internals.username
