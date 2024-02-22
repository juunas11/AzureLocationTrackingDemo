import {
  PublicClientApplication,
  type AccountInfo,
  type AuthenticationResult,
  InteractionRequiredAuthError,
} from "@azure/msal-browser";

const msalApp = new PublicClientApplication({
  auth: {
    clientId: import.meta.env.VITE_AAD_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${
      import.meta.env.VITE_AAD_TENANT_ID
    }`,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
});

export function initialize(
  handleLoginResponse: (response: AuthenticationResult | null) => void
) {
  msalApp.initialize().then((x) => {
    msalApp
      .handleRedirectPromise()
      .then(handleLoginResponse)
      .catch((err) => {
        console.error(err);
      });
  });
}

export function setActiveAccount(account: AccountInfo) {
  msalApp.setActiveAccount(account);
}

export function getAllAccounts() {
  return msalApp.getAllAccounts();
}

export function login() {
  msalApp.loginRedirect({
    scopes: [import.meta.env.VITE_AAD_API_SCOPE],
  });
}

export function getAccessToken() {
  return msalApp
    .acquireTokenSilent({
      scopes: [import.meta.env.VITE_AAD_API_SCOPE],
    })
    .then((tokenResponse) => {
      return tokenResponse.accessToken;
    })
    .catch((err) => {
      if (err instanceof InteractionRequiredAuthError) {
        return msalApp.loginRedirect({
          scopes: [import.meta.env.VITE_AAD_API_SCOPE],
        });
      }

      console.error(err);
    });
}
