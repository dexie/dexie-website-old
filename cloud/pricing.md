---
layout: dexie-cloud-pricing
title: 'Dexie Cloud Pricing'
---

## Prod Support

This support option is included when subscribing to Dexie Cloud Production (SaaS) and includes email and chat support.

## Silver Support

This support option is available for the On-Prem Silver Edition. One year of Silver Support is included when purchasing Dexie Cloud On-Prem Silver and includes:

- Chat support
- Email support
- Prioritized tickets
- Software updates
- Github issues

Price: $695 per year.

## Gold Support

Every customer is different and require different levels of support. With the Gold Support package, we can dedicate our support to your team, tailor SLAs and be available at the levels of customer's requirements.

The basic level of Gold Support that is included in On-Prem Gold edition includes:

- SLA 16 business hours
- Access to private GIT repo of Dexie Cloud Server for source code updates
- Prioritized tickets
- Private Github issues
- Software updates
- Chat support
- Email support
- Video meetings
- Dedication

Price (basic level): $3,495/yr

# Detailed Pricing Table

For more details, check out [this blog post](https://medium.com/dexie-js/dexie-cloud-subscription-model-cbf9a709ce7).

|                                                                   | Free (SaaS)               | Production (SaaS)                     | On-prem Silver / Gold                                       |
| ----------------------------------------------------------------- | ------------------------- | ------------------------------------- | ----------------------------------------------------------- |
| Easy setup: **[npx dexie-cloud create](/cloud/#getting-started)** | ✔                         | ✔                                     | See [these docs](docs/premium-software)                     |
| All main features included                                        | ✔                         | ✔                                     | ✔                                                           |
| [Customizable authentication](#customizable-authentication)       | ✔                         | ✔                                     | ✔                                                           |
| [Replaceable authentication](#replaceable-authentication)         | ✔                         | ✔                                     | ✔                                                           |
| [Custom email templates](/cloud/docs/custom-emails)               | -                         | ✔                                     | ✔                                                           |
| Vertically scalable                                               | -                         | ✔                                     | ✔                                                           |
| Horizontally scalable                                             | -                         | ✔                                     | ✔                                                           |
| Max Number of databases                                           | Unlimited, free of charge | Unlimited, free of charge             | Unlimited                                                   |
| [Evaluation users](#evaluation-users) (your end users)            | Unlimited, free of charge | Unlimited, free of charge             | Unlimited                                                   |
| [Demo accounts](#demo-accounts) (for showcasing app)              | Unlimited, free of charge | Unlimited, free of charge             | Unlimited                                                   |
| [Production users](#production-users) (your end users)            | 3 seats, free of charge   | USD $3/mo per 25 seats                | Unlimited                                                   |
| Storage                                                           | 100 MB                    | See [storage limits](#storage-limits) | Unlimited                                                   |
| Simultanous Client Connections                                    | 10                        | 200 per 100 users                     | Unlimited                                                   |
| Sync rate-limits                                                  | 50 per 5 mins per user    | 200 per 5 minutes per user            | Configurable                                                |
| Software updates (client)                                         | ✔ (via npm)               | ✔ (via npm)                           | ✔ (via npm)                                                 |
| Software updates (server)                                         | N/A                       | N/A                                   | ✔ (via git, npm or download)                                |
| Full source code                                                  | -                         | -                                     | [On-Prem Gold](#gold-edition)                               |
| Access to private Git repo                                        | -                         | -                                     | [On-Prem Gold](#gold-edition)                               |
| Support options                                                   | Github or Stackoverflow   | Email / chat                          | [Silver](#silver-support)- or [Gold](#gold-support) Support |

## Storage Limits

Dexie Cloud Production includes storage in relation to the number of seats purchased. The storage limit is computed on the sum of storage and not per individual user. If additional storage would be needed, it can be added to the subscription for a separate storage fee (see second table below).

Storage limits are differentiated between blob- and object data. Normal object data (strings, numbers, arrays, Date, etc) reside in object storage in PostgeSQL while blob data (Blobs stored in object properties) are synced to a blob storage.

| Seats&nbsp;  | Included Object storage&nbsp; | Included Blob storage&nbsp; | Included Blob write operations |
| ------------ | ----------------------------- | --------------------------- | ------------------------------ |
| Free edition | 25 MB                         | 75 MB                       | 1,000 / mo                     |
| 25           | 1 GB                          | 20 GB                       | 50,000 / mo                    |
| 50           | 2 GB                          | 40 GB                       | 100,000 / mo                   |
| 75           | 3 GB                          | 60 GB                       | 150,000 / mo                   |
| 100          | 4 GB                          | 80 GB                       | 200,000 / mo                   |
| ...          | ...                           | ...                         | ...                            |
| 1000         | 20 GB                         | 800 GB                      | 2,000,000 / mo                 |
| 10 000       | 200 GB                        | 8 TB                        | 20,000,000 / mo                |
| 100 000      | 2 TB                          | 80 TB                       | 200,000,000 / mo               |
| ...          | ...                           | ...                         |

The storage limit is specified on the total subscription and does not have to be distributed equally between the users. Normally the majority of users might not come close to the limit, which will allow the more active users to take more - without having to purchase additional storage for the subscription.

A Blob write operation is counted when a blob is created or updated (replaced).

### Additional Storage

If more storage or write frequency than what's already included in the price would be requested, a subscription can be extended with additional storage and write operations:

| Storage Type   | Storage Cost              | Sync costs                                      |
| -------------- | ------------------------- | ----------------------------------------------- |
| Blob Storage   | USD $0.05 / extra GB / mo | USD $0.5 per 10,000 additional write operations |
| Object Storage | USD $2 / extra GB / mo    |                                                 |

### Blob- vs Object Storage

To make use of the cheaper Blob storage, save large binary data such as images, songs, videos etc in Blobs rather than base64 encoded strings or UInt8Arrays. The storage type can be affected already at the client side by using the [Blob](https://developer.mozilla.org/en-US/docs/Web/API/Blob) datatype in Dexie.js. The rest is handled by dexie-cloud:

```ts
async function addMp3Song(title: string, genre: string, mp3Blob: Blob) {
  await db.songs.add({
    title, // goes into object storage at sync time
    genre, // goes into object storage at sync time
    songData: mp3Blob // goes into blob storage at sync time
  });
}
```

Note however, that unlike object storage, blob storage has a limit / cost associated with write operations. Every time a blob is added or replaced is considered a write operation.

## Free

This edition is hosted and forever free. Let your app accept unlimited number of evaluation users and up to 3 production users. An end user's evaluation period will be paused on days when there are no sync requests from that user. After a user's evaluation period ends (30 active days), they can continue using your application offline, but data syncing will stop unless the user is upgraded to production. Upgrading a user can be done manually or programmatically. If more than 3 production seats are needed, existing databases can be upgraded to the [Production](#production) edition.

<a class='btn btn-success' href='/cloud/#getting-started' role='button'>Get started now &raquo;</a>

## Production

This edition is hosted and starts at USD $3 per month for 25 seats. It works similarly to the [Free](#free) edition but with more seats, storage and more generous API rate limits. Continue enjoying free evaluation users on top of the 100 production seats. You control which users occupy production seats via the Dexie Cloud Management app or REST API. Integrate this REST API with the web hooks of your payment gateway (e.g., Stripe, Paypal) to manage seats based on your subscription with customers. When the number of production end users reaches 100, you can manually purchase more seat-packs or let the subscription automatically upgrade or downgrade as needed.

<a class='btn btn-success' href='https://buy.stripe.com/14k9CEgSne5D1BS8ww' role='button'>Buy now &raquo;</a>

## Dexie Cloud Server Software

Purchase the software (optionally with full source code and private Git access) and utilize it as you wish (modify source code or taylor it for your systems - anything except [competing with us](server-software-license-terms)). Serve millions of users without additional fees. Host it on a cloud provider of your choice or your own hardware. The server is compatible with cloud platforms like Amazon AWS and Microsoft Azure. The package includes one year of chat- and email support and software updates. For continuous support, the yearly fee covers ongoing updates, chat- and email support.

<a href='/cloud/docs/premium-software'>Read more... &raquo;</a>

<a class='btn btn-success' href='https://buy.stripe.com/8wM8yAfOjf9HbcsfZ0' role='button'>Buy now &raquo;</a>

<!-- <a class='btn btn-success' href='/cloud/purchase/software' role='button'>Get it now &raquo;</a> -->

---

## End User Types

This section outlines the distinctions between Evaluation, Production, and Demo users as referenced in the pricing table. Dexie Cloud provides a security layer of [authentication](/cloud/docs/authentication) and [access control](/cloud/docs/access-control) directly between end-user and database. End users will authenticate directly with Dexie Cloud database but via a customizable authentication experience for the end user.

### Evaluation Users

Evaluation users are free time-limited end user accounts for your app, that can be upgraded to production at any time. By default, Dexie Cloud allows anyone to authenticate (configurable). Unknown users do not occupy seats but receive an evaluation license for up to 30 active days. Evaluation accounts are paused on inactive days (configurable). After an evaluation period ends, the user can continue using the app but won't be able to sync data. You can indicate the user's evaluation status and prompt them to upgrade. Upgrade evaluation users to production via the Dexie Cloud Management app or REST API.

### Production Users

A production user occupies one of the production seats. The Evaluation edition includes 3 free production seats, while the Production edition comes in 25-seat packs. Manage production seat occupancy via the Dexie Cloud Management app or REST API. Integrate this API with payment gateway web hooks to manage seats based on your customer subscriptions.

### Demo Accounts

Demo accounts are for testing and demoing your app. They lack login credentials and are useful for showcasing data sharing. Like any other user account, demo accounts do not have access to any private data that hasn't been actively shared to it. Enable or disable demo accounts as needed. Demo accounts do not occupy seats and do not expire.

Find more about Dexie Cloud and its features by visiting the [Dexie Cloud Documentation](/cloud/docs/).

## Customized Authentication

In all editions, it is possible to replace or customize end-user authentication. Dexie Cloud comes with OTP authentication and a default GUI that prompts the user for email and One-time password. There's no need to write any backend or even front-end code for this. However, customers may want to either customise the user interface, or integrate with an existing authentication solution instead of using the built-in OTP authentication from Dexie Cloud.

### Customizable Authentication

To customize the default GUI for our OTP authentication, [configure `{customLoginGui: true}`](</cloud/docs/db.cloud.configure()>) and let a component use the [`db.cloud.userInteraction` observable](/cloud/docs/dexie-cloud-addon) to display dialogs with your own look and feel. Customized authentication does not need a custom backend but can be served the way you prefer, and even from a static web site.

### Replaceable Authentication

To replace the default OTP authentication with your own authentication of choice, you'll need a backend-for-frontend (BFF) server side app to serve your client application. The server-side app needs to serve a dedicated token endpoint for dexie-cloud client that integrates with your authentication solution. See [this guide](</cloud/docs/db.cloud.configure()#example-integrate-custom-authentication>) on how it can be accomplished.

<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>
