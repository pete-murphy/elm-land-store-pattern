module Pages.Home_ exposing (Data, Model, Msg, page)

import Api.Post as Post
import Api.Tag as Tag
import Api.User as User
import Auth
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError exposing (DetailedError)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import Shared.Model
import Store exposing (PaginatedStrategy(..), Strategy(..))
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user shared
        , update = update
        , view = view user shared
        , subscriptions = subscriptions
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Data a =
    Loadable DetailedError a


type alias Model =
    {}


init : Auth.User -> Shared.Model -> () -> ( Model, Effect Msg )
init user _ _ =
    ( {}
    , Effect.batch
        [ Effect.sendStoreRequest StaleWhileRevalidate
            (Tag.get user.credentials)
        , Effect.sendStoreRequestPaginated Reset
            (User.list user.credentials { limit = 5 })
        , Effect.sendStoreRequestPaginated Reset
            (Post.list user.credentials { limit = 5, status = Nothing, search = Nothing })
        ]
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Auth.User -> Shared.Model -> Model -> View Msg
view user shared _ =
    let
        store =
            Shared.Model.store shared

        tags =
            Store.get (Tag.get user.credentials) store.unpaginated

        users =
            Store.getAll (User.list user.credentials { limit = 5 }) store.paginated

        posts =
            Store.getAll (Post.list user.credentials { limit = 5, status = Nothing, search = Nothing }) store.paginated
    in
    { title = "Home"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ viewSection
                { title = "Tags"
                , apiData = tags
                , view = Tag.viewList
                }
            , viewSection
                { title = "Users"
                , apiData = users
                , view = User.viewPreviewList
                }
            , viewSection
                { title = "Posts"
                , apiData = posts
                , view = Post.viewPreviewList
                }
            ]
        ]
    }


viewSection : { title : String, apiData : Data a, view : a -> Html msg } -> Html msg
viewSection props =
    Html.section [ Attributes.class "flex flex-col gap-4" ]
        [ Html.h2 [ Attributes.class "text-xl font-bold" ]
            [ Html.text props.title ]
        , case Loadable.value props.apiData of
            Loadable.Empty ->
                viewSkeletonSectionContent

            Loadable.Failure error ->
                Html.text (DetailedError.toString error)

            Loadable.Success value ->
                props.view value
        ]


viewSkeletonSectionContent : Html msg
viewSkeletonSectionContent =
    Html.div [ Attributes.class "flex flex-col gap-4 p-4 bg-gray-100 rounded-md animate-pulse min-h-40" ]
        []
