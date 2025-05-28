module Pages.Users.UserId_ exposing (Model, Msg, page)

import Accessibility as Html exposing (Html)
import Api.Post exposing (Post)
import Api.User exposing (User)
import Api.UserId as UserId
import Auth
import Components.LocaleTime as LocaleTime
import Effect exposing (Effect)
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
import Store exposing (PaginatedStrategy(..), Store, Strategy(..))
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { userId : String } -> Page Model Msg
page user shared route =
    let
        userId =
            UserId.fromRoute route

        requests =
            { user = Api.User.getById user.credentials userId
            , posts = Api.Post.listByUser user.credentials userId { limit = 10 }
            }
    in
    Page.new
        { init = init requests shared
        , update = update
        , subscriptions = subscriptions
        , view = view requests (Shared.Model.store shared)
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Data a =
    Loadable DetailedError a


type alias Requests =
    { user : Request (User Api.User.Details)
    , posts : Request (Paginated (Post Api.Post.Preview))
    }


type alias Model =
    {}


init : Requests -> Shared.Model -> () -> ( Model, Effect Msg )
init requests shared _ =
    ( {}
    , Effect.batch
        [ Effect.sendStoreRequest (Shared.Model.strategy shared) requests.user
        , Effect.sendStoreRequestPaginated (Shared.Model.paginatedStrategy shared) requests.posts
        ]
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Requests -> Store -> Model -> View Msg
view requests store _ =
    case Loadable.value (Store.get requests.user store) of
        Loadable.Empty ->
            { title = "Loading..."
            , body = [ viewSkeletonContent ]
            }

        Loadable.Failure error ->
            { title = "Error"
            , body =
                [ Html.div [ Attributes.class "p-4 bg-red-50 rounded-md" ]
                    [ Html.h2 [ Attributes.class "mb-2 text-lg font-semibold text-red-800" ]
                        [ Html.text "Error loading user" ]
                    , Html.p [ Attributes.class "text-red-700" ]
                        [ Html.text (Http.DetailedError.toString error) ]
                    ]
                ]
            }

        Loadable.Success user ->
            { title = Api.User.fullName user
            , body = [ viewUser user (Store.get requests.posts store) ]
            }


viewUser : User Api.User.Details -> Data (Paginated (Post Api.Post.Preview)) -> Html Msg
viewUser user postsData =
    Html.article [ Attributes.class "flex flex-col gap-6" ]
        [ Html.header [ Attributes.class "flex gap-6 items-start" ]
            [ Html.img ""
                [ Attributes.class "w-24 h-24 rounded-full"
                , Attributes.src (Api.User.avatarUrl user)
                ]
            , Html.div [ Attributes.class "flex-1" ]
                [ Html.div [ Attributes.class "mb-3 font-bold" ]
                    [ Html.text ("@" ++ Api.User.username user) ]
                , Html.div [ Attributes.class "flex gap-2 items-center mb-3 text-sm text-gray-600" ]
                    [ Html.text (Api.User.roleToString (Api.User.role user))
                    , Html.text " • "
                    , Html.text
                        (if Api.User.isActive user then
                            "Active"

                         else
                            "Inactive"
                        )
                    ]
                , Html.div [ Attributes.class "flex gap-1 text-sm text-gray-600" ]
                    (Html.div [] [ Html.text "Joined" ]
                        :: (LocaleTime.new (Api.User.createdAt user)
                                |> LocaleTime.withTimeStyle Nothing
                                |> LocaleTime.withLocaleAttrs []
                                |> LocaleTime.withRelativeAttrs
                                    [ Attributes.class "before:content-['('] after:content-[')']"
                                    ]
                                |> LocaleTime.toHtml
                           )
                    )
                ]
            ]
        , case Api.User.bio user of
            Just bioText ->
                Html.div [ Attributes.class "max-w-none prose" ]
                    [ Html.h3 [ Attributes.class "mb-3 text-lg font-semibold" ]
                        [ Html.text "About" ]
                    , Html.p [ Attributes.class "text-gray-700 whitespace-pre-wrap" ]
                        [ Html.text bioText ]
                    ]

            Nothing ->
                Html.text ""
        , Html.div [ Attributes.class "pt-6 border-t border-gray-200" ]
            [ Html.h3 [ Attributes.class "mb-3 text-sm font-semibold text-gray-600" ]
                [ Html.text "Contact" ]
            , Html.div [ Attributes.class "text-sm text-gray-700" ]
                [ Html.text ("Email: " ++ Api.User.email user) ]
            ]
        , Html.div [ Attributes.class "pt-6 border-t border-gray-200" ]
            [ Html.h3 [ Attributes.class "mb-6 text-lg font-semibold" ]
                [ Html.text "Posts" ]
            , viewPostsSection postsData
            ]
        ]


viewPostsSection : Data (Paginated (Post Api.Post.Preview)) -> Html Msg
viewPostsSection postsData =
    case Loadable.value postsData of
        Loadable.Empty ->
            viewPostsSkeletonContent

        Loadable.Failure error ->
            Html.div [ Attributes.class "p-4 bg-red-50 rounded-md" ]
                [ Html.h4 [ Attributes.class "mb-2 text-lg font-semibold text-red-800" ]
                    [ Html.text "Error loading posts" ]
                , Html.p [ Attributes.class "text-red-700" ]
                    [ Html.text (Http.DetailedError.toString error) ]
                ]

        Loadable.Success paginatedPosts ->
            if List.isEmpty paginatedPosts.data then
                Html.div [ Attributes.class "py-8 text-center text-gray-500" ]
                    [ Html.text "No posts yet" ]

            else
                Api.Post.viewPreviewList paginatedPosts.data


viewPostsSkeletonContent : Html msg
viewPostsSkeletonContent =
    Html.div [ Attributes.class "flex flex-col gap-4" ]
        [ Html.div [ Attributes.class "animate-pulse" ]
            [ Html.div [ Attributes.class "mb-2 w-3/4 h-6 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-2 w-1/2 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "w-full h-4 bg-gray-200 rounded" ] []
            ]
        , Html.div [ Attributes.class "animate-pulse" ]
            [ Html.div [ Attributes.class "mb-2 w-2/3 h-6 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-2 w-1/3 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "w-5/6 h-4 bg-gray-200 rounded" ] []
            ]
        ]


viewSkeletonContent : Html msg
viewSkeletonContent =
    Html.div [ Attributes.class "flex flex-col gap-6" ]
        [ Html.div [ Attributes.class "animate-pulse" ]
            [ Html.div [ Attributes.class "flex gap-6 items-start mb-6" ]
                [ Html.div [ Attributes.class "w-24 h-24 bg-gray-200 rounded-full" ] []
                , Html.div [ Attributes.class "flex-1" ]
                    [ Html.div [ Attributes.class "mb-2 w-1/2 h-8 bg-gray-200 rounded" ] []
                    , Html.div [ Attributes.class "mb-2 w-2/3 h-4 bg-gray-200 rounded" ] []
                    , Html.div [ Attributes.class "w-1/3 h-4 bg-gray-200 rounded" ] []
                    ]
                ]
            , Html.div [ Attributes.class "mb-2 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "mb-2 h-4 bg-gray-200 rounded" ] []
            , Html.div [ Attributes.class "w-3/4 h-4 bg-gray-200 rounded" ] []
            ]
        ]
