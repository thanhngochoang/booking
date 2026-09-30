package com.paditech.mvpbase.screen.album;

import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 12/1/2017.
 */

public interface AlbumContact {
    interface ViewOps extends FragmentViewOps {
        void onUpdateAlbums(ArrayList<Album> albums);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void getMyAlbums(String id);
    }
}
