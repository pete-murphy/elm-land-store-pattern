module Pages.Home_ exposing (Data, Model, Msg, page)

import Api.Post as Post exposing (Post)
import Api.Tag as Tag exposing (Tag)
import Api.User as User exposing (User)
import Auth
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError exposing (DetailedError)
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


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    let
        requests =
            { tags = Tag.get user.credentials
            , users = User.list user.credentials { limit = 5 }
            , posts = Post.list user.credentials { limit = 5, status = Nothing, search = Nothing }
            }
    in
    Page.new
        { init = init requests shared
        , update = update
        , view = view requests (Shared.Model.store shared)
        , subscriptions = subscriptions
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Data a =
    Loadable DetailedError a


type alias Requests =
    { tags : Request (List Tag)
    , users : Request (Paginated (User User.Preview))
    , posts : Request (Paginated (Post Post.Preview))
    }


type alias Model =
    {}


init : Requests -> Shared.Model -> () -> ( Model, Effect Msg )
init requests shared _ =
    ( {}
    , Effect.batch
        [ Effect.sendStoreRequest (Shared.Model.strategy shared) requests.tags
        , Effect.sendStoreRequest (Shared.Model.strategy shared) requests.users
        , Effect.sendStoreRequest (Shared.Model.strategy shared) requests.posts
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


view : Requests -> Store -> Model -> View Msg
view requests store model =
    { title = "Home"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ viewSection
                { title = "Tags"
                , apiData = Store.get requests.tags store
                , view = Tag.viewList
                }
            , viewSection
                { title = "Users"
                , apiData = Store.get requests.users store |> Loadable.map .data
                , view = User.viewPreviewList
                }
            , viewSection
                { title = "Posts"
                , apiData = Store.get requests.posts store |> Loadable.map .data
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
