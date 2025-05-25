module Api.Comment exposing
    ( Comment
    , CreateCommentRequest
    , UpdateCommentRequest
    , author
    , content
    , create
    , createdAt
    , decoder
    , delete
    , get
    , id
    , isDeleted
    , parentComment
    , post
    , update
    , updatedAt
    )

import Api.Post as Post exposing (Post)
import Api.User as User exposing (User)
import Auth.Credentials as Credentials exposing (Credentials)
import Http
import Http.Extra exposing (Request)
import Iso8601
import Json.Decode exposing (Decoder)
import Json.Decode.Pipeline
import Json.Encode as Encode
import Paginated exposing (Paginated)
import Time exposing (Posix)
import Url.Builder


type Comment
    = Comment CommentData


type alias CommentData =
    { id : String
    , content : String
    , author : User User.Preview
    , post : Post Post.Preview
    , parentComment : Maybe Comment
    , isDeleted : Bool
    , createdAt : Posix
    , updatedAt : Posix
    }



-- JSON


decoder : Decoder Comment
decoder =
    Json.Decode.succeed CommentData
        |> Json.Decode.Pipeline.required "id" Json.Decode.string
        |> Json.Decode.Pipeline.required "content" Json.Decode.string
        |> Json.Decode.Pipeline.required "author" User.previewDecoder
        |> Json.Decode.Pipeline.required "post" Post.previewDecoder
        |> Json.Decode.Pipeline.required "parentComment" (Json.Decode.nullable (Json.Decode.lazy (\_ -> decoder)))
        |> Json.Decode.Pipeline.required "isDeleted" Json.Decode.bool
        |> Json.Decode.Pipeline.required "createdAt" Iso8601.decoder
        |> Json.Decode.Pipeline.required "updatedAt" Iso8601.decoder
        |> Json.Decode.map Comment



-- HTTP


get :
    Credentials
    -> String
    -> { page : Int, limit : Int, parentOnly : Bool }
    -> Request (Paginated Comment)
get credentials postId params =
    let
        queryParams =
            [ Url.Builder.int "page" params.page
            , Url.Builder.int "limit" params.limit
            ]
                ++ (if params.parentOnly then
                        [ Url.Builder.string "parent_only" "true" ]

                    else
                        []
                   )
    in
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "posts", postId, "comments" ] queryParams
    , body = Http.emptyBody
    , decoder = Paginated.decoder decoder
    }


type alias CreateCommentRequest =
    { content : String
    , parentCommentId : Maybe String
    }


create :
    Credentials
    -> String
    -> CreateCommentRequest
    -> Request Comment
create credentials postId request =
    let
        requestBody =
            Encode.object
                ([ ( "content", Encode.string request.content ) ]
                    ++ (case request.parentCommentId of
                            Just parentId ->
                                [ ( "parentCommentId", Encode.string parentId ) ]

                            Nothing ->
                                []
                       )
                )
    in
    { method = "POST"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "posts", postId, "comments" ] []
    , body = Http.jsonBody requestBody
    , decoder = decoder
    }


type alias UpdateCommentRequest =
    { content : String
    }


update :
    Credentials
    -> String
    -> UpdateCommentRequest
    -> Request Comment
update credentials commentId request =
    { method = "PATCH"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "comments", commentId ] []
    , body =
        Http.jsonBody
            (Encode.object
                [ ( "content", Encode.string request.content )
                ]
            )
    , decoder = decoder
    }


delete :
    Credentials
    -> String
    -> Request ()
delete credentials commentId =
    { method = "DELETE"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "comments", commentId ] []
    , body = Http.emptyBody
    , decoder = Json.Decode.succeed ()
    }



-- GETTERS


id : Comment -> String
id (Comment data) =
    data.id


content : Comment -> String
content (Comment data) =
    data.content


author : Comment -> User User.Preview
author (Comment data) =
    data.author


post : Comment -> Post Post.Preview
post (Comment data) =
    data.post


parentComment : Comment -> Maybe Comment
parentComment (Comment data) =
    data.parentComment


isDeleted : Comment -> Bool
isDeleted (Comment data) =
    data.isDeleted


createdAt : Comment -> Posix
createdAt (Comment data) =
    data.createdAt


updatedAt : Comment -> Posix
updatedAt (Comment data) =
    data.updatedAt
