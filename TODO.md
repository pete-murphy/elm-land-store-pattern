- [x] Refactor `Request` to use URL parts
- [x] Combine `.paginated` + `.unpaginated` into single `Dict`
- [x] Validate (don't parse) JSON 😛
- [ ] Consolidate strategies(?) and put them in a separate module
- [x] Refactor `CustomElements.intersectionSentinel` to `IntersectionObservee` with builder pattern

      ```elm
      IntersectionObservee.new { onIntersect : UserScrolledToBottom }
          |> IntersectionObservee.withDisabled (..)
          |> IntersectionObservee.withChildren (..)
          |> IntersectionObservee.withOffset -- ?
      ```

- [ ] Move to Store pattern
- [ ] Error handling / logging in general
      This would happen via a custom element that emits an event when an observed attribute changes (stringified JSON of the error)
- [ ] N + 1 queries (using intersection observer?)
