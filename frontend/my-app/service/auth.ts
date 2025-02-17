import { CognitoUserPool, CognitoUser, AuthenticationDetails } from 'amazon-cognito-identity-js';

const poolData = {
  UserPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID!,
  ClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!
};

const userPool = new CognitoUserPool(poolData);

export const auth = {
  signIn: (email: string, password: string): Promise<any> => {
    return new Promise((resolve, reject) => {
      const authenticationDetails = new AuthenticationDetails({
        Username: email,
        Password: password,
      });

      const cognitoUser = new CognitoUser({
        Username: email,
        Pool: userPool
      });

      cognitoUser.authenticateUser(authenticationDetails, {
        onSuccess: (result) => {
          resolve(result);
        },
        onFailure: (err) => {
          reject(err);
        }
      });
    });
  },

  signOut: () => {
    const currentUser = userPool.getCurrentUser();
    if (currentUser) {
      currentUser.signOut();
    }
  },

  getCurrentUser: (): Promise<any> => {
    return new Promise((resolve, reject) => {
      const currentUser = userPool.getCurrentUser();
      if (!currentUser) {
        reject(new Error('No user found'));
        return;
      }

      currentUser.getSession((err: any, session: any) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(currentUser);
      });
    });
  },

  getSession: (): Promise<any> => {
    return new Promise((resolve, reject) => {
      const currentUser = userPool.getCurrentUser();
      if (!currentUser) {
        reject(new Error('No user found'));
        return;
      }

      currentUser.getSession((err: any, session: any) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(session);
      });
    });
  }
}; 