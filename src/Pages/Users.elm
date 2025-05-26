module Pages.Users exposing (Model, Msg, page)

import Api.User exposing (Preview, User)
import Auth
import Auth.Credentials exposing (Credentials)
import CustomElements
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError exposing (DetailedError)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Paginated exposing (Paginated)
import Route exposing (Route)
import Shared
import Store exposing (PaginatedStrategy(..))
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user shared
        , update = update
        , view = view
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
    { users : Data (Paginated (User Preview))
    , credentials : Credentials
    }


init : Auth.User -> Shared.Model -> () -> ( Model, Effect Msg )
init user _ _ =
    ( { users = Loadable.loading
      , credentials = user.credentials
      }
    , Effect.sendStoreRequestPaginated NextPage
        (Api.User.list user.credentials { limit = 10 })
    )



-- UPDATE


type Msg
    = UserScrolledToBottom
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        UserScrolledToBottom ->
            ( model
            , Effect.sendStoreRequestPaginated NextPage
                (Api.User.list model.credentials { limit = 10 })
            )

        NoOp ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Users"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ viewUsersSection model.users
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
                , CustomElements.intersectionSentinel
                    { onIntersect = UserScrolledToBottom
                    , disabled = Loadable.isLoading usersData
                    }
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
