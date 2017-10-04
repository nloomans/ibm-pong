# Credly Widget
[![JavaScript Style Guide](https://img.shields.io/badge/code%20style-standard-brightgreen.svg)](http://standardjs.com/) [![Travis](https://img.shields.io/travis/nloomans/coderclass-ranking.svg?maxAge=2592000)](https://travis-ci.org/nloomans/coderclass-ranking)

## Setup

1. install [nodejs](https://nodejs.org/en/download/package-manager/), v6 recommended, v4+ supported.
2. run `npm run setup` to install the npm and bower dependencies
3. add `/credly_options.json` to the repository
3. run `npm start` to run the server, or keep `npm run dev` running in the
    background while developing.

### Adding `/env.json`

The `/env.json` file should look like this:

```json
{
  "API_KEY": "place api key here",
  "API_SECRET": "place api secret here"
}
```

You can also pass them as environment variables.

## Documentation

### Display earned badges of a user

 - **url**: `/user/$userId/`
 - **$userId**: The ID of the user

### Display a table of who has earned what

 - **url**: `/table/$issuerId/$badgeId`
 - **$issuerId**: The id of the user that created the master badge
 - **$badgeId**: The id of the master badge itself

The master badge is a badge that everyone has.

### Display users that earned a specific badge

 - **url**: `/badge-details/$issuerId/$badgeId`
 - **$issuerId**: The id of the user that created the badge
 - **$badgeId**: The id of the badge itself
