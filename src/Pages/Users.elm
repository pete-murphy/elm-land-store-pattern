module Pages.Users exposing (Model, Msg, page)

import Api.User exposing (Preview, User)
import Auth
import Components.IntersectionObservee as IntersectionObservee
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
import Store exposing (Store)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    let
        requests =
            { users = Api.User.list user.credentials { limit = 10 }
            }
    in
    Page.new
        { init = init requests shared
        , update = update requests shared
        , view = view requests (Shared.Model.store shared)
        , subscriptions = subscriptions
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Requests =
    { users : Request (Paginated (User Preview))
    }


type alias Model =
    {}


init : Requests -> Shared.Model -> () -> ( Model, Effect Msg )
init requests shared _ =
    ( {}
    , Effect.sendStoreRequestPaginated (Shared.Model.paginatedStrategy shared) requests.users
    )



-- UPDATE


type Msg
    = UserScrolledToBottom
    | NoOp


update : Requests -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update requests shared msg model =
    case msg of
        UserScrolledToBottom ->
            ( model
            , Effect.sendStoreRequestPaginated (Shared.Model.paginatedStrategy shared) requests.users
            )

        NoOp ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


type alias Data a =
    Loadable DetailedError a


view : Requests -> Store -> Model -> View Msg
view requests store model =
    { title = "Users"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ viewUsersSection (Store.get requests.users store)
            ]
        ]
    }


viewUsersSection : Data (Paginated (User Preview)) -> Html Msg
viewUsersSection usersData =
    case Loadable.value usersData of
        Loadable.Empty ->
            viewSkeletonContent

        Loadable.Failure error ->
            Html.text (DetailedError.toString error)

        Loadable.Success paginatedUsers ->
            Html.div [ Attributes.class "flex flex-col gap-4" ]
                [ Api.User.viewPreviewList paginatedUsers.data
                , IntersectionObservee.new UserScrolledToBottom
                    |> IntersectionObservee.withDisabled (Loadable.isLoading usersData)
                    |> IntersectionObservee.toHtml
                , if Loadable.isLoading usersData then
                    viewSkeletonContent

                  else
                    Html.text ""
                ]


viewSkeletonContent : Html msg
viewSkeletonContent =
    Html.div [ Attributes.class "flex flex-col gap-6" ]
        (List.repeat 4
            (Html.div [ Attributes.class "bg-gray-100 rounded-md animate-pulse min-h-20" ]
                []
            )
        )
