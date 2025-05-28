module Pages.Posts.Slug_ exposing (Model, Msg, page)

import Api.Comment as Comment exposing (Comment)
import Api.Post exposing (Details, Post)
import Api.Slug as Slug
import Api.Tag as Tag
import Api.User as User
import Auth
import Components.IntersectionObservee as IntersectionObservee
import Components.LocaleTime as LocaleTime
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError exposing (DetailedError)
import Http.Extra exposing (Request)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Paginated exposing (Paginated)
import Route exposing (Route)
import Shared
import Shared.Model
import Store exposing (Store, Strategy(..))
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { slug : String } -> Page Model Msg
page user shared route =
    let
        slug =
            Slug.fromRoute route

        requests =
            { post = Api.Post.get user.credentials slug
            , comments = \post -> Comment.get user.credentials (Api.Post.id post) { limit = 50, parentOnly = False }
            }
    in
    Page.new
        { init = init requests shared
        , update = update requests shared
        , subscriptions = subscriptions
        , view = view requests (Shared.Model.store shared)
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Requests =
    { post : Request (Post Details)
    , comments : Post Details -> Request (Paginated Comment)
    }


type alias Model =
    {}


init : Requests -> Shared.Model -> () -> ( Model, Effect Msg )
init requests shared () =
    ( {}
    , Effect.sendStoreRequest (Shared.Model.strategy shared) requests.post
    )



-- UPDATE


type Msg
    = UserScrolledToBottom (Post Details)
    | NoOp


update : Requests -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update requests shared msg model =
    case msg of
        UserScrolledToBottom post ->
            ( model
            , Effect.sendStoreRequest (Shared.Model.strategy shared) (requests.comments post)
            )

        NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


type alias Data a =
    Loadable DetailedError a


view : Requests -> Store -> Model -> View Msg
view requests store _ =
    case Loadable.value (Store.get requests.post store) of
        Loadable.Empty ->
            { title = "Loading..."
            , body = [ viewSkeletonContent ]
            }

        Loadable.Failure error ->
            { title = "Error"
            , body =
                [ Html.div [ Attributes.class "p-4 bg-red-50 rounded-md" ]
                    [ Html.h2 [ Attributes.class "mb-2 text-lg font-semibold text-red-800" ]
                        [ Html.text "Error loading post" ]
                    , Html.p [ Attributes.class "text-red-700" ]
                        [ Html.text (Http.DetailedError.toString error) ]
                    ]
                ]
            }

        Loadable.Success post ->
            { title = Api.Post.title post
            , body = [ viewPost post (Store.get (requests.comments post) store) ]
            }


viewPost : Post Api.Post.Details -> Data (Paginated Comment) -> Html Msg
viewPost post comments =
    Html.article [ Attributes.class "flex flex-col gap-6" ]
        [ Html.header []
            [ Html.div [ Attributes.class "flex gap-2 items-center mb-4 text-sm text-gray-600" ]
                [ Html.text ("by " ++ username (Api.Post.author post))
                , Html.text " • "
                , Html.text (Api.Post.statusToString (Api.Post.status post))
                , Html.text " • "
                , Html.text (String.fromInt (Api.Post.viewCount post) ++ " views")
                ]
            , Html.div [ Attributes.class "flex gap-1 mb-6 text-sm text-gray-600" ]
                (LocaleTime.new (Api.Post.createdAt post)
                    |> LocaleTime.withTimeStyle Nothing
                    |> LocaleTime.withLocaleAttrs []
                    |> LocaleTime.withRelativeAttrs []
                    |> LocaleTime.toHtml
                    |> List.intersperse (Html.text " • ")
                )
            ]
        , Html.div [ Attributes.class "max-w-none prose" ]
            [ Html.p [ Attributes.class "mb-6 text-lg text-gray-600" ]
                [ Html.text (Api.Post.excerpt post) ]
            , Html.div [ Attributes.class "text-gray-900 whitespace-pre-wrap" ]
                [ Html.text (Api.Post.content post) ]
            ]
        , Html.footer []
            [ if List.isEmpty (Api.Post.tags post) then
                Html.text ""

              else
                Html.div [ Attributes.class "pt-6 border-t border-gray-200" ]
                    [ Html.h3 [ Attributes.class "mb-3 text-sm font-semibold text-gray-600" ]
                        [ Html.text "Tags" ]
                    , Tag.viewList (Api.Post.tags post)
                    ]
            ]
        , viewComments comments
        , IntersectionObservee.new (UserScrolledToBottom post)
            |> IntersectionObservee.withDisabled (Loadable.isLoading comments || Loadable.value comments /= Loadable.Empty)
            |> IntersectionObservee.toHtml
        ]


viewComments : Data (Paginated Comment) -> Html Msg
viewComments commentsData =
    Html.div [ Attributes.class "pt-6 border-t border-gray-200" ]
        [ Html.h3 [ Attributes.class "mb-4 text-lg font-semibold text-gray-900" ]
            [ Html.text "Comments" ]
        , case Loadable.value commentsData of
            Loadable.Empty ->
                Html.div [ Attributes.class "animate-pulse" ]
                    [ Html.div [ Attributes.class "mb-4 h-16 bg-gray-200 rounded" ] []
                    , Html.div [ Attributes.class "mb-4 h-16 bg-gray-200 rounded" ] []
                    ]

            Loadable.Failure error ->
                Html.div [ Attributes.class "p-4 bg-red-50 rounded-md" ]
                    [ Html.p [ Attributes.class "text-red-700" ]
                        [ Html.text ("Error loading comments: " ++ Http.DetailedError.toString error) ]
                    ]

            Loadable.Success paginatedComments ->
                if List.isEmpty paginatedComments.data then
                    Html.p [ Attributes.class "italic text-gray-500" ]
                        [ Html.text "No comments yet." ]

                else
                    Html.ul [ Attributes.class "flex flex-col gap-4" ]
                        (List.map viewComment paginatedComments.data)
        ]


viewComment : Comment -> Html Msg
viewComment comment =
    Html.li [ Attributes.class "p-4 bg-gray-50 rounded-lg" ]
        [ Html.div [ Attributes.class "flex gap-2 items-center mb-2 text-sm text-gray-600" ]
            [ Html.text ("by " ++ username (Comment.author comment))
            , Html.text " • "
            , Html.span []
                (LocaleTime.new (Comment.createdAt comment)
                    |> LocaleTime.withTimeStyle Nothing
                    |> LocaleTime.withLocaleAttrs []
                    |> LocaleTime.withRelativeAttrs []
                    |> LocaleTime.toHtml
                    |> List.intersperse (Html.text " • ")
                )
            ]
        , Html.p [ Attributes.class "text-gray-900" ]
            [ Html.text (Comment.content comment) ]
        ]


viewSkeletonContent : Html msg
viewSkeletonContent =
    Html.div [ Attributes.class "flex flex-col gap-6" ]
        [ Html.div [ Attributes.class "animate-pulse" ]
            [ Html.div [ Attributes.class "mb-4 h-8 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-2 w-1/2 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-6 w-1/3 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-2 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-2 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-2 w-3/4 h-4 bg-gray-200 rounded" ] []
            ]
        ]


username : User.User User.Preview -> String
username (User.User internals _) =
    internals.username
