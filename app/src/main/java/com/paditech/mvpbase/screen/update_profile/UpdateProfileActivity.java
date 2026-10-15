package com.paditech.mvpbase.screen.update_profile;

import android.Manifest;
import android.accounts.AccountManager;
import android.annotation.SuppressLint;
import android.app.Dialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.googleapis.extensions.android.gms.auth.GoogleAccountCredential;
import com.google.api.client.googleapis.extensions.android.gms.auth.GooglePlayServicesAvailabilityIOException;
import com.google.api.client.googleapis.extensions.android.gms.auth.UserRecoverableAuthIOException;
import com.google.api.client.http.HttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.client.util.DateTime;
import com.google.api.client.util.ExponentialBackOff;
import com.google.api.services.calendar.Calendar;
import com.google.api.services.calendar.CalendarScopes;
import com.google.api.services.calendar.model.Event;
import com.google.api.services.calendar.model.Events;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.utils.CommonUtil;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;
import com.paditech.mvpbase.common.utils.get_image.GetImageManager;
import com.paditech.mvpbase.common.view.PriceEditText;
import com.paditech.mvpbase.screen.main.MainActivity;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import butterknife.BindView;
import butterknife.OnClick;
import de.hdodenhof.circleimageview.CircleImageView;

/**
 * Created by Fx570ex on 08-12-2017.
 */

public class UpdateProfileActivity extends MVPActivity<UpdateProfileContact.PresenterViewOps>
        implements UpdateProfileContact.ViewOps {
    private static final String[] SCOPES = {CalendarScopes.CALENDAR};
    private static final int PERMISSION_GET_ACC = 101;
    private static final int OPEN_ACC_PICKER = 201;
    private static final int OPEN_AUTHENTICATION = 202;
    private static final int REQUEST_GOOGLE_PLAY_SERVICES = 301;

    @BindView(R.id.avatar)
    CircleImageView avatar;
    @BindView(R.id.et_name)
    EditText etName;
    @BindView(R.id.et_address)
    EditText etAddress;
    @BindView(R.id.et_phone)
    EditText etPhone;
    @BindView(R.id.et_body)
    EditText etBody;
    @BindView(R.id.et_lens)
    EditText etLens;
    @BindView(R.id.et_gear_other)
    EditText etGearOther;
    @BindView(R.id.et_syle)
    EditText etSyle;
    @BindView(R.id.submit_area)
    Button submitArea;
    @BindView(R.id.et_price)
    PriceEditText etPrice;
    @BindView(R.id.btn_gg_calendar)
    Button btnGoogleCalendar;

    private GoogleAccountCredential mGoogleAccountCredential;
    private GetImageManager mGetImageManager;
    private String mUserId;

    @Override
    protected int getContentView() {
        return R.layout.frag_update_profile;
    }

    @Override
    protected void initView() {
        mUserId = getIntent().getStringExtra("user_id");
        if (StringUtil.isEmpty(mUserId)) mUserId = PrefUtil.getUid();
        if (!PrefUtil.getUid().equals(mUserId)) {
            etPhone.setEnabled(false);
            etGearOther.setEnabled(false);
            etBody.setEnabled(false);
            etLens.setEnabled(false);
            etSyle.setEnabled(false);
            etPrice.setEnabled(false);
            etAddress.setEnabled(false);
            etName.setEnabled(false);
            submitArea.setVisibility(View.GONE);
        }
        CommonUtil.dismissSoftKeyboard(findViewById(R.id.main_layout), this);
        mGetImageManager = new GetImageManager(this, avatar);
        setupCalendarAPI();
        setupProfile();
        if (!StringUtil.isEmpty(PrefUtil.getCalendarAccount(this))) {
            btnGoogleCalendar.setText(R.string.connected_gg_calendar);
        }
    }

    private void setupCalendarAPI() {
        mGoogleAccountCredential = GoogleAccountCredential.usingOAuth2(getActivityContext(), Arrays.asList(SCOPES))
                .setBackOff(new ExponentialBackOff());
    }


    private void setupProfile() {
        try {
            User user = PrefUtil.getUser(this);
            if (user == null) return;
            etName.setText(user.getFull_name());
            ImageUtil.loadImage(this, user.getAvatar(), avatar, R.color.white, R.color.white);
            if (user.isIs_photographer()) {
                etAddress.setText(user.getAddress());
                etPrice.setText(String.valueOf(user.getPrice()));
                etSyle.setText(user.getStyle());
                etLens.setText(user.getCamera_lens());
                etBody.setText(user.getCamera_body());
                etGearOther.setText(user.getGear_other());
                etPhone.setText(user.getPhone_number());
                if (!StringUtil.isEmpty(user.getGoogle_calendar_account())) {
                    btnGoogleCalendar.setText(String.format(getString(R.string.connected_gg_calendar), user.getGoogle_calendar_account()));
                } else {
                    btnGoogleCalendar.setText(R.string.connect_gg_calendar);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected Class<? extends ActivityPresenter> onRegisterPresenter() {
        return UpdateProfilePresenter.class;
    }

    public void goToHome() {
        hideProgressbar();
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }


    @OnClick({R.id.avatar, R.id.submit_area})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.avatar:
                mGetImageManager.onAddImage();
                break;
            case R.id.submit_area:
                if (validate()) {
                    User photographer = PrefUtil.getUser(this);
                    if (photographer != null) {
                        photographer.setId(PrefUtil.getUid());
                        photographer.setFull_name(etName.getText().toString().trim());
                        photographer.setAddress(etAddress.getText().toString().trim());
                        photographer.setPhone_number(etPhone.getText().toString().trim());
                        photographer.setCamera_body(etBody.getText().toString().trim());
                        photographer.setCamera_lens(etLens.getText().toString().trim());
                        photographer.setGear_other(etGearOther.getText().toString().trim());
                        photographer.setStyle(etSyle.getText().toString().trim());
                        photographer.setPrice(etPrice.getPrice());
                        photographer.setIs_photographer(true);
                        if (PrefUtil.getCalendarAccount(this) != null)
                            photographer.setGoogle_calendar_account(PrefUtil.getCalendarAccount(this));
                        if (!StringUtil.isEmpty(mGetImageManager.getmImageFilePath())) {
                            getPresenter().savePhotographer(mGetImageManager.getmImageFilePath(), photographer);
                        } else {
                            getPresenter().savePhotographer(null, photographer);
                        }

                    }
                }
                break;
        }
    }

    private boolean validate() {
        if (StringUtil.isEmpty(etName.getText().toString().trim())) {
            showToast(getString(R.string.mess_name_empty));
            return false;
        }
        if (StringUtil.isEmpty(etAddress.getText().toString().trim())) {
            showToast(getString(R.string.mess_address_empty));
            return false;
        }
        if (StringUtil.isEmpty(etBody.getText().toString().trim())) {
            showToast(getString(R.string.mess_empty_ed_body));
            return false;
        }
        if (StringUtil.isEmpty(etLens.getText().toString().trim())) {
            showToast(getString(R.string.mess_empty_lens));
            return false;
        }
        if (StringUtil.isEmpty(etSyle.getText().toString().trim())) {
            showToast(getString(R.string.mess_empty_style));
            return false;
        }
        if (StringUtil.isEmpty(etPrice.getText().toString().trim())) {
            showToast(getString(R.string.mess_price_empty));
            return false;
        }
        if (etPrice.getPrice() <= 0) {
            showToast(getString(R.string.mess_price_invalid));
            return false;
        }
        return true;
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        mGetImageManager.onActivityResult(requestCode, resultCode, data);
        switch (requestCode) {
            case REQUEST_GOOGLE_PLAY_SERVICES:
                if (resultCode != RESULT_OK) {
                    Toast.makeText(getActivityContext(), "This app requires Google Play Services. Please install " +
                            "Google Play Services on your device and relaunch this app.", Toast.LENGTH_SHORT).show();
                } else {
                    getResultsFromApi();
                }
                break;
            case OPEN_ACC_PICKER:
                if (resultCode == RESULT_OK && data != null &&
                        data.getExtras() != null) {
                    String accountName =
                            data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME);
                    if (accountName != null) {
                        PrefUtil.saveCalendarAccount(getActivityContext(), accountName);
                        mGoogleAccountCredential.setSelectedAccountName(accountName);
                        btnGoogleCalendar.setText(String.format(getString(R.string.connected_gg_calendar), accountName));
                        getResultsFromApi();
                    }
                }
                break;
            case OPEN_AUTHENTICATION:
                if (resultCode == RESULT_OK) {
                    getResultsFromApi();
                }
                break;
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        mGetImageManager.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public void onBackPressed() {
        showConfirmDialog(getString(R.string.mess_confirm_back), new BaseDialog.OnPositiveClickListener() {
            @Override
            public void onPositiveClick() {
                goToHome();
            }
        }, new BaseDialog.OnNegativeClickListener() {
            @Override
            public void onNegativeClick() {

            }
        });

    }

    @Override
    public void onSaveSuccess() {
        showToast(getString(R.string.save_photographer_success));
        goToHome();
    }

    @Override
    public void onFailed(String message) {
        showError(message);
    }

    private void getResultsFromApi() {
        if (!isGooglePlayServicesAvailable()) {
            acquireGooglePlayServices();
        } else if (mGoogleAccountCredential.getSelectedAccountName() == null) {
            chooseAccount();
        } else if (!isDeviceOnline()) {
            Toast.makeText(getActivityContext(), "No network connection available.", Toast.LENGTH_SHORT).show();
        } else {
            new MakeRequestTask(mGoogleAccountCredential).execute();
        }
    }

    private void chooseAccount() {
        String account = PrefUtil.getCalendarAccount(getActivityContext());
        if (!StringUtil.isEmpty(account)) {
            mGoogleAccountCredential.setSelectedAccountName(account);
            getResultsFromApi();
        } else {
            if (ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.GET_ACCOUNTS)
                    == PackageManager.PERMISSION_GRANTED) {
                startActivityForResult(
                        mGoogleAccountCredential.newChooseAccountIntent(),
                        OPEN_ACC_PICKER);

            } else {
                ActivityCompat.requestPermissions(getActivity(),
                        new String[]{Manifest.permission.GET_ACCOUNTS},
                        PERMISSION_GET_ACC);
            }
        }

    }


    private boolean isDeviceOnline() {
        ConnectivityManager connMgr =
                (ConnectivityManager) getActivityContext().getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo networkInfo = null;
        if (connMgr != null) {
            networkInfo = connMgr.getActiveNetworkInfo();
        }
        return (networkInfo != null && networkInfo.isConnected());
    }

    private boolean isGooglePlayServicesAvailable() {
        GoogleApiAvailability apiAvailability =
                GoogleApiAvailability.getInstance();
        final int connectionStatusCode =
                apiAvailability.isGooglePlayServicesAvailable(getActivityContext());
        return connectionStatusCode == ConnectionResult.SUCCESS;
    }

    private void acquireGooglePlayServices() {
        GoogleApiAvailability apiAvailability =
                GoogleApiAvailability.getInstance();
        final int connectionStatusCode =
                apiAvailability.isGooglePlayServicesAvailable(getActivityContext());
        if (apiAvailability.isUserResolvableError(connectionStatusCode)) {
            showGooglePlayServicesAvailabilityErrorDialog(connectionStatusCode);
        }
    }

    void showGooglePlayServicesAvailabilityErrorDialog(
            final int connectionStatusCode) {
        GoogleApiAvailability apiAvailability = GoogleApiAvailability.getInstance();
        Dialog dialog = apiAvailability.getErrorDialog(
                getActivity(),
                connectionStatusCode,
                REQUEST_GOOGLE_PLAY_SERVICES);
        dialog.show();
    }


    @OnClick({R.id.btn_flickr, R.id.btn_gg_calendar})
    public void onConnectSocial(View view) {
        switch (view.getId()) {
            case R.id.btn_flickr:
                break;
            case R.id.btn_gg_calendar:
                getResultsFromApi();
                break;
        }
    }

    @SuppressLint("StaticFieldLeak")
    private class MakeRequestTask extends AsyncTask<Void, Void, List<String>> {
        private Calendar mService = null;
        private Exception mLastError = null;

        MakeRequestTask(GoogleAccountCredential credential) {
            HttpTransport transport = new NetHttpTransport();
            GsonFactory jsonFactory = GsonFactory.getDefaultInstance();
            mService = new Calendar.Builder(
                    transport, jsonFactory, credential)
                    .setApplicationName("Google Calendar API Android Quickstart")
                    .build();
        }

        /**
         * Background task to call Google Calendar API.
         *
         * @param params no parameters needed for this task.
         */
        @Override
        protected List<String> doInBackground(Void... params) {
            try {
                return getDataFromApi();
            } catch (Exception e) {
                mLastError = e;
                cancel(true);
                return null;
            }
        }

        /**
         * Fetch a list of the next 10 events from the primary calendar.
         *
         * @return List of Strings describing returned events.
         * @throws IOException
         */
        private List<String> getDataFromApi() throws IOException {
            // List the next 10 events from the primary calendar.
            DateTime now = new DateTime(System.currentTimeMillis());
            List<String> eventStrings = new ArrayList<String>();
            Events events = mService.events().list("primary")
                    .setMaxResults(10)
                    .setTimeMin(now)
                    .setOrderBy("startTime")
                    .setSingleEvents(true)
                    .execute();
            List<Event> items = events.getItems();

            for (Event event : items) {
                DateTime start = event.getStart().getDateTime();
                if (start == null) {
                    // All-day events don't have start times, so just use
                    // the start date.
                    start = event.getStart().getDate();
                }
                eventStrings.add(
                        String.format("%s (%s)", event.getSummary(), start));
            }
            return eventStrings;
        }


        @Override
        protected void onPreExecute() {
            showProgressbar();
        }

        @Override
        protected void onPostExecute(List<String> output) {
            hideProgressbar();
            if (output == null || output.size() == 0) {
                Log.e("TAG", "No results returned.");
            } else {
                output.add(0, "Data retrieved using the Google Calendar API:");
                Log.e("TAG", TextUtils.join("\n", output));
            }
        }

        @Override
        protected void onCancelled() {
            hideProgressbar();
            if (mLastError != null) {
                if (mLastError instanceof GooglePlayServicesAvailabilityIOException) {
                    showGooglePlayServicesAvailabilityErrorDialog(
                            ((GooglePlayServicesAvailabilityIOException) mLastError)
                                    .getConnectionStatusCode());
                } else if (mLastError instanceof UserRecoverableAuthIOException) {
                    startActivityForResult(
                            ((UserRecoverableAuthIOException) mLastError).getIntent(),
                            OPEN_AUTHENTICATION);
                } else {
                    Log.e("TAG", "The following error occurred:\n"
                            + mLastError.getMessage());
                }
            } else {
                Log.e("TAG", "Request cancelled.");
            }
        }
    }
}
